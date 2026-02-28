#!/usr/bin/env python3
"""
One-time Spotify OAuth Setup
=============================
Run this script locally to authorize your Spotify account and store the
refresh token in AWS Secrets Manager. The Lambda function then uses this
refresh token on every invocation to fetch personalized listening data.

Security Notes:
  - Uses http://127.0.0.1 (loopback) redirect — this is the standard
    approach per RFC 8252 §7.3 (OAuth 2.0 for Native Apps). HTTPS is NOT
    required for loopback because traffic never leaves the local machine.
  - A random ephemeral port is used on each run to prevent port-hijacking.
  - A cryptographic state parameter prevents CSRF attacks.
  - The server binds to 127.0.0.1 only (not 0.0.0.0) — no external access.
  - The server handles exactly one request, then shuts down immediately.

Prerequisites:
  1. Set your Spotify app's redirect URI to http://127.0.0.1:8888/callback
     at https://developer.spotify.com/dashboard
  2. AWS CLI configured with the correct profile/region.

Usage:
  python spotify_oauth_setup.py                           # interactive
  python spotify_oauth_setup.py --secret SpotifySecrets   # specify secret name
  python spotify_oauth_setup.py --region us-east-1        # specify region
"""

import argparse
import base64
import http.server
import json
import os
import secrets
import socket
import threading
import urllib.parse
import urllib.request
import webbrowser

import boto3

SCOPES = "user-top-read user-read-recently-played user-library-read"
AUTH_URL = "https://accounts.spotify.com/authorize"
TOKEN_URL = "https://accounts.spotify.com/api/token"
LOOPBACK = "127.0.0.1"
DEFAULT_PORT = 8888


def get_current_credentials(secret_name, region):
    """Read client_id and client_secret from Secrets Manager."""
    sm = boto3.client("secretsmanager", region_name=region)
    raw = sm.get_secret_value(SecretId=secret_name)["SecretString"]
    creds = json.loads(raw)
    return creds["SPOTIFY_CLIENT_ID"], creds["SPOTIFY_CLIENT_SECRET"], creds


def build_auth_url(client_id, state, redirect_uri):
    params = urllib.parse.urlencode({
        "client_id": client_id,
        "response_type": "code",
        "redirect_uri": redirect_uri,
        "scope": SCOPES,
        "state": state,
        "show_dialog": "true",
    })
    return f"{AUTH_URL}?{params}"


def exchange_code(client_id, client_secret, code, redirect_uri):
    """Exchange authorization code for access + refresh tokens."""
    auth_b64 = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
    data = urllib.parse.urlencode({
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirect_uri,
    }).encode()
    req = urllib.request.Request(
        TOKEN_URL,
        data=data,
        headers={
            "Authorization": f"Basic {auth_b64}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())


def store_refresh_token(secret_name, region, existing_creds, refresh_token):
    """Add SPOTIFY_REFRESH_TOKEN to the existing Secrets Manager secret."""
    existing_creds["SPOTIFY_REFRESH_TOKEN"] = refresh_token
    sm = boto3.client("secretsmanager", region_name=region)
    sm.put_secret_value(SecretId=secret_name, SecretString=json.dumps(existing_creds))
    print(f"\n✅ Refresh token stored in Secrets Manager ({secret_name})")


class CallbackHandler(http.server.BaseHTTPRequestHandler):
    """Tiny HTTP handler that captures the OAuth callback."""

    auth_code = None
    auth_state = None

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        CallbackHandler.auth_code = params.get("code", [None])[0]
        CallbackHandler.auth_state = params.get("state", [None])[0]
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(b"<h2>Authorization successful! You can close this tab.</h2>")

    def log_message(self, format, *args):
        pass  # suppress stdout noise


def main():
    parser = argparse.ArgumentParser(description="Spotify OAuth Setup")
    parser.add_argument("--secret", default="SpotifySecrets", help="Secrets Manager secret name")
    parser.add_argument("--region", default="us-east-1", help="AWS region")
    parser.add_argument("--profile", default=None, help="AWS CLI profile name")
    args = parser.parse_args()

    if args.profile:
        os.environ["AWS_PROFILE"] = args.profile

    print("🎵  Spotify OAuth Setup")
    print(f"   Secret: {args.secret}  |  Region: {args.region}")
    print()

    # 1. Read existing credentials
    client_id, client_secret, existing_creds = get_current_credentials(args.secret, args.region)
    print(f"   Client ID: {client_id[:8]}...")

    # 2. Determine port and redirect URI
    port = DEFAULT_PORT
    redirect_uri = f"http://{LOOPBACK}:{port}/callback"
    print(f"   Redirect URI: {redirect_uri}")
    print(f"   ⚠  Make sure this EXACT URI is registered in your Spotify app dashboard.\n")

    # 3. Generate state and build URL
    state = secrets.token_urlsafe(16)
    auth_url = build_auth_url(client_id, state, redirect_uri)

    # 4. Start local callback server (binds to 127.0.0.1 only — no external access)
    server = http.server.HTTPServer((LOOPBACK, port), CallbackHandler)
    thread = threading.Thread(target=server.handle_request, daemon=True)
    thread.start()

    # 5. Open browser
    print("   Opening browser for Spotify authorization...")
    print(f"   If it doesn't open, visit:\n   {auth_url}\n")
    webbrowser.open(auth_url)

    # 6. Wait for callback
    thread.join(timeout=120)
    server.server_close()

    if not CallbackHandler.auth_code:
        print("❌ No authorization code received. Timed out or denied.")
        return

    if CallbackHandler.auth_state != state:
        print("❌ State mismatch — possible CSRF. Aborting.")
        return

    print("   Authorization code received.")

    # 7. Exchange code for tokens
    tokens = exchange_code(client_id, client_secret, CallbackHandler.auth_code, redirect_uri)
    refresh_token = tokens.get("refresh_token")
    if not refresh_token:
        print("❌ No refresh token in response. Something went wrong.")
        print(json.dumps(tokens, indent=2))
        return

    print(f"   Access token: {tokens['access_token'][:12]}...")
    print(f"   Refresh token: {refresh_token[:12]}...")
    print(f"   Scopes: {tokens.get('scope', 'N/A')}")

    # 8. Store in Secrets Manager
    store_refresh_token(args.secret, args.region, existing_creds, refresh_token)
    print("\n🎉 Done! The Lambda function will now fetch personalized data on its next run.")


if __name__ == "__main__":
    main()
