"""Portfolio Spotify API — Lambda Handler

Routes both EventBridge (scheduled new-releases refresh) and API Gateway v2
(HTTP user requests) through a single Lambda function for cost efficiency.

Architecture:
  EventBridge → lambda_handler → handle_scheduled_refresh → S3 (public data)
  API Gateway → lambda_handler → ROUTES dict → per-route handler → DynamoDB / Spotify
"""
import json
import os
import base64
import hashlib
import secrets
import time
import uuid
import urllib.request
import urllib.parse
import urllib.error
import calendar

import boto3
from boto3.dynamodb.conditions import Key


# ─── Configuration ───────────────────────────────────────────────────────────
REGION = os.environ.get("AWS_REGION", "us-east-1")
S3_BUCKET = os.environ.get("S3_BUCKET_NAME")
SECRET_NAME = os.environ.get("SECRET_NAME")
KMS_KEY_ID = os.environ.get("KMS_KEY_ID")
USERS_TABLE = os.environ.get("USERS_TABLE")
TOKENS_TABLE = os.environ.get("TOKENS_TABLE")
SESSIONS_TABLE = os.environ.get("SESSIONS_TABLE")
INSIGHTS_TABLE = os.environ.get("INSIGHTS_TABLE")
WEBSITE_DOMAIN = os.environ.get("WEBSITE_DOMAIN")
SPOTIFY_REDIRECT_URI = os.environ.get("SPOTIFY_REDIRECT_URI")

OWNER_SPOTIFY_USER_ID = os.environ.get("OWNER_SPOTIFY_USER_ID", "")
POLICY_VERSION = os.environ.get("POLICY_VERSION", "2026-02-27")
ACCESS_REQUESTS_TABLE = os.environ.get("ACCESS_REQUESTS_TABLE")
PLAY_HISTORY_TABLE = os.environ.get("PLAY_HISTORY_TABLE")
ADMIN_EMAIL = os.environ.get("ADMIN_EMAIL", "")
SES_FROM_EMAIL = os.environ.get("SES_FROM_EMAIL", "")

SPOTIFY_SCOPES = "user-read-recently-played user-top-read user-read-email user-read-private playlist-modify-public"
SESSION_MAX_AGE = 86400           # 24 hours (regular users)
OWNER_SESSION_MAX_AGE = 31536000  # 365 days (owner)
AUTH_STATE_TTL = 600              # 10 minutes
INSIGHT_CACHE_TTL = 3600          # 1 hour


# ─── AWS Clients (module-level for warm-start reuse) ─────────────────────────
_s3 = None
_dynamodb = None
_kms = None
_sm = None


def _get_s3():
    global _s3
    if _s3 is None:
        _s3 = boto3.client("s3", region_name=REGION)
    return _s3


def _get_dynamodb():
    global _dynamodb
    if _dynamodb is None:
        _dynamodb = boto3.resource("dynamodb", region_name=REGION)
    return _dynamodb


def _get_kms():
    global _kms
    if _kms is None:
        _kms = boto3.client("kms", region_name=REGION)
    return _kms


def _get_sm():
    global _sm
    if _sm is None:
        _sm = boto3.client("secretsmanager", region_name=REGION)
    return _sm


_ses = None


def _get_ses():
    global _ses
    if _ses is None:
        _ses = boto3.client("ses", region_name=REGION)
    return _ses


def _send_email(to_email, subject, body_html, body_text=""):
    """Send email via SES. Silently fails if SES is not configured."""
    if not SES_FROM_EMAIL or not to_email:
        return False
    try:
        ses = _get_ses()
        ses.send_email(
            Source=SES_FROM_EMAIL,
            Destination={"ToAddresses": [to_email]},
            Message={
                "Subject": {"Data": subject, "Charset": "UTF-8"},
                "Body": {
                    "Html": {"Data": body_html, "Charset": "UTF-8"},
                    "Text": {"Data": body_text or subject, "Charset": "UTF-8"},
                },
            },
        )
        return True
    except Exception:
        return False


# ─── HTTP Helper ─────────────────────────────────────────────────────────────
def _http_request(url, headers=None, data=None, method="GET"):
    """Make an HTTP request using urllib (no external dependencies)."""
    if data and isinstance(data, dict):
        data = urllib.parse.urlencode(data).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers or {}, method=method)
    try:
        with urllib.request.urlopen(req) as response:
            body = response.read().decode("utf-8")
            return {"status": response.status, "body": json.loads(body)}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        return {"status": e.code, "body": body}


# ─── Spotify App Credentials ────────────────────────────────────────────────
def _get_spotify_app_credentials():
    """Retrieve Spotify client_id and client_secret from Secrets Manager."""
    sm = _get_sm()
    resp = sm.get_secret_value(SecretId=SECRET_NAME)
    raw = resp.get("SecretString") or base64.b64decode(resp["SecretBinary"]).decode()
    creds = json.loads(raw)
    return creds["SPOTIFY_CLIENT_ID"], creds["SPOTIFY_CLIENT_SECRET"]


def _get_client_token(client_id, client_secret):
    """Get a Client Credentials token for public endpoints."""
    auth_b64 = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
    result = _http_request(
        "https://accounts.spotify.com/api/token",
        headers={
            "Authorization": f"Basic {auth_b64}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        data={"grant_type": "client_credentials"},
        method="POST",
    )
    if result["status"] != 200:
        raise RuntimeError(f"Client Credentials auth failed: {result['body']}")
    return result["body"]["access_token"]


# ─── PKCE Helpers ────────────────────────────────────────────────────────────
def _generate_pkce():
    """Generate PKCE code_verifier and code_challenge (S256)."""
    verifier = secrets.token_urlsafe(64)[:128]
    challenge = base64.urlsafe_b64encode(
        hashlib.sha256(verifier.encode("ascii")).digest()
    ).rstrip(b"=").decode("ascii")
    return verifier, challenge


# ─── KMS Helpers ─────────────────────────────────────────────────────────────
def _encrypt_token(plaintext):
    """Encrypt a string with KMS envelope encryption."""
    kms = _get_kms()
    resp = kms.encrypt(KeyId=KMS_KEY_ID, Plaintext=plaintext.encode("utf-8"))
    return base64.b64encode(resp["CiphertextBlob"]).decode("ascii")


def _decrypt_token(ciphertext_b64):
    """Decrypt a KMS-encrypted string."""
    kms = _get_kms()
    resp = kms.decrypt(CiphertextBlob=base64.b64decode(ciphertext_b64))
    return resp["Plaintext"].decode("utf-8")


# ─── Cookie Helpers ──────────────────────────────────────────────────────────
def _parse_cookies(cookie_header):
    """Parse a Cookie header string into a dict."""
    cookies = {}
    if not cookie_header:
        return cookies
    for part in cookie_header.split(";"):
        part = part.strip()
        if "=" in part:
            k, v = part.split("=", 1)
            cookies[k.strip()] = v.strip()
    return cookies


def _make_session_cookie(session_id, max_age=SESSION_MAX_AGE):
    """Create a Set-Cookie header value with security flags."""
    return (
        f"session_id={session_id}; "
        f"HttpOnly; Secure; SameSite=Lax; "
        f"Path=/; Max-Age={max_age}; "
        f"Domain={WEBSITE_DOMAIN}"
    )


def _clear_session_cookie():
    """Create a Set-Cookie header to expire the session cookie."""
    return (
        f"session_id=; HttpOnly; Secure; SameSite=Lax; "
        f"Path=/; Max-Age=0; "
        f"Domain={WEBSITE_DOMAIN}"
    )


# ─── DynamoDB Session Helpers ────────────────────────────────────────────────
def _put_auth_state(state, code_verifier):
    """Store an OAuth state + PKCE verifier with short TTL (10 min)."""
    table = _get_dynamodb().Table(SESSIONS_TABLE)
    table.put_item(Item={
        "session_id": f"auth#{state}",
        "type": "auth_state",
        "code_verifier": code_verifier,
        "created_at": int(time.time()),
        "expires_at": int(time.time()) + AUTH_STATE_TTL,
    })


def _get_and_delete_auth_state(state):
    """Retrieve and delete an OAuth state record. Returns code_verifier or None."""
    table = _get_dynamodb().Table(SESSIONS_TABLE)
    resp = table.get_item(Key={"session_id": f"auth#{state}"})
    item = resp.get("Item")
    if not item:
        return None
    # Always delete the state (one-time use)
    table.delete_item(Key={"session_id": f"auth#{state}"})
    if item.get("expires_at", 0) < int(time.time()):
        return None
    return item.get("code_verifier")


def _create_session(user_id, max_age=SESSION_MAX_AGE):
    """Create a new server session. Returns session_id."""
    session_id = secrets.token_urlsafe(32)
    table = _get_dynamodb().Table(SESSIONS_TABLE)
    now = int(time.time())
    table.put_item(Item={
        "session_id": session_id,
        "type": "session",
        "user_id": user_id,
        "created_at": now,
        "expires_at": now + max_age,
    })
    return session_id


def _get_session(session_id):
    """Get user_id from session. Returns None if expired or missing.
    Auto-extends owner sessions on each access."""
    if not session_id:
        return None
    table = _get_dynamodb().Table(SESSIONS_TABLE)
    resp = table.get_item(Key={"session_id": session_id})
    item = resp.get("Item")
    if not item or item.get("type") != "session":
        return None
    now = int(time.time())
    if item.get("expires_at", 0) < now:
        table.delete_item(Key={"session_id": session_id})
        return None
    user_id = item.get("user_id")
    # Auto-extend owner sessions on each access
    if user_id and _is_owner_user_id(user_id):
        remaining = item["expires_at"] - now
        if remaining < OWNER_SESSION_MAX_AGE // 2:
            table.update_item(
                Key={"session_id": session_id},
                UpdateExpression="SET expires_at = :ea",
                ExpressionAttributeValues={":ea": now + OWNER_SESSION_MAX_AGE},
            )
    return user_id


def _delete_session(session_id):
    """Delete a session record."""
    if not session_id:
        return
    table = _get_dynamodb().Table(SESSIONS_TABLE)
    table.delete_item(Key={"session_id": session_id})


# ─── DynamoDB User Helpers ───────────────────────────────────────────────────
def _find_or_create_user(spotify_user_id, display_name, email, country=""):
    """Find existing user by spotify_user_id (GSI) or create a new one."""
    table = _get_dynamodb().Table(USERS_TABLE)
    resp = table.query(
        IndexName="spotify-user-id-index",
        KeyConditionExpression=Key("spotify_user_id").eq(spotify_user_id),
    )
    items = resp.get("Items", [])
    now = int(time.time())

    if items:
        user_id = items[0]["user_id"]
        update_expr = "SET display_name = :dn, email = :em, updated_at = :ua"
        expr_vals = {":dn": display_name, ":em": email, ":ua": now}
        if country:
            update_expr += ", country = :co"
            expr_vals[":co"] = country
        table.update_item(
            Key={"user_id": user_id},
            UpdateExpression=update_expr,
            ExpressionAttributeValues=expr_vals,
        )
        return user_id

    user_id = str(uuid.uuid4())
    item = {
        "user_id": user_id,
        "spotify_user_id": spotify_user_id,
        "display_name": display_name,
        "email": email,
        "policy_acknowledged": POLICY_VERSION,
        "created_at": now,
        "updated_at": now,
    }
    if country:
        item["country"] = country
    table.put_item(Item=item)
    return user_id


# ─── Owner Helpers ───────────────────────────────────────────────────────────
_owner_user_id_cache = None


def _is_owner_spotify_id(spotify_user_id):
    """Check if a Spotify user ID belongs to the site owner."""
    return bool(OWNER_SPOTIFY_USER_ID) and spotify_user_id == OWNER_SPOTIFY_USER_ID


def _is_owner_user_id(user_id):
    """Check if an internal user_id belongs to the site owner."""
    owner_uid = _get_owner_user_id()
    return owner_uid is not None and user_id == owner_uid


def _get_owner_user_id():
    """Get the owner's internal user_id from their Spotify user ID (cached)."""
    global _owner_user_id_cache
    if _owner_user_id_cache is not None:
        return _owner_user_id_cache
    if not OWNER_SPOTIFY_USER_ID:
        return None
    table = _get_dynamodb().Table(USERS_TABLE)
    resp = table.query(
        IndexName="spotify-user-id-index",
        KeyConditionExpression=Key("spotify_user_id").eq(OWNER_SPOTIFY_USER_ID),
    )
    items = resp.get("Items", [])
    if items:
        _owner_user_id_cache = items[0]["user_id"]
        return _owner_user_id_cache
    return None


# ─── DynamoDB Token Helpers ──────────────────────────────────────────────────
def _store_encrypted_token(user_id, refresh_token):
    """Encrypt and store a Spotify refresh token."""
    encrypted = _encrypt_token(refresh_token)
    table = _get_dynamodb().Table(TOKENS_TABLE)
    table.put_item(Item={
        "user_id": user_id,
        "encrypted_refresh_token": encrypted,
        "updated_at": int(time.time()),
    })


def _get_user_access_token(user_id):
    """Retrieve encrypted refresh token, decrypt, exchange for access token."""
    table = _get_dynamodb().Table(TOKENS_TABLE)
    resp = table.get_item(Key={"user_id": user_id})
    item = resp.get("Item")
    if not item:
        return None

    refresh_token = _decrypt_token(item["encrypted_refresh_token"])
    client_id, client_secret = _get_spotify_app_credentials()

    auth_b64 = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
    result = _http_request(
        "https://accounts.spotify.com/api/token",
        headers={
            "Authorization": f"Basic {auth_b64}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        data={"grant_type": "refresh_token", "refresh_token": refresh_token},
        method="POST",
    )
    if result["status"] != 200:
        raise RuntimeError(f"Token refresh failed: {result['body']}")

    body = result["body"]
    new_refresh = body.get("refresh_token")
    if new_refresh and new_refresh != refresh_token:
        _store_encrypted_token(user_id, new_refresh)

    return body["access_token"]


# ─── DynamoDB Insight Cache ──────────────────────────────────────────────────
def _get_cached_insight(user_id, insight_type):
    """Get cached insight data if still fresh."""
    table = _get_dynamodb().Table(INSIGHTS_TABLE)
    resp = table.get_item(Key={"user_id": user_id, "insight_key": insight_type})
    item = resp.get("Item")
    if not item or item.get("expires_at", 0) < int(time.time()):
        return None
    return json.loads(item.get("data", "null"))


def _cache_insight(user_id, insight_type, data):
    """Cache derived insight data in DynamoDB with TTL."""
    table = _get_dynamodb().Table(INSIGHTS_TABLE)
    now = int(time.time())
    table.put_item(Item={
        "user_id": user_id,
        "insight_key": insight_type,
        "data": json.dumps(data),
        "created_at": now,
        "expires_at": now + INSIGHT_CACHE_TTL,
    })


# ─── Spotify Data Fetch Helpers ──────────────────────────────────────────────
def _fetch_new_releases(token):
    """Fetch public new album releases."""
    result = _http_request(
        "https://api.spotify.com/v1/browse/new-releases?limit=20",
        headers={"Authorization": f"Bearer {token}"},
    )
    if result["status"] != 200:
        return []
    items = result["body"].get("albums", {}).get("items", [])
    return [
        {
            "name": a["name"],
            "artist": ", ".join(art["name"] for art in a.get("artists", [])),
            "url": a["external_urls"].get("spotify", ""),
            "image": a["images"][0]["url"] if a.get("images") else "",
            "release_date": a.get("release_date", ""),
        }
        for a in items
    ]


def _fetch_top_artists(token):
    """Fetch user's top artists (medium term ~6 months)."""
    result = _http_request(
        "https://api.spotify.com/v1/me/top/artists?limit=20&time_range=medium_term",
        headers={"Authorization": f"Bearer {token}"},
    )
    if result["status"] != 200:
        return []
    return [
        {
            "name": a["name"],
            "url": a["external_urls"].get("spotify", ""),
            "image": a["images"][0]["url"] if a.get("images") else "",
            "genres": a.get("genres", []),
            "popularity": a.get("popularity", 0),
        }
        for a in result["body"].get("items", [])
    ]


def _fetch_top_tracks(token, time_range="medium_term"):
    """Fetch user's top tracks for a given time range."""
    result = _http_request(
        f"https://api.spotify.com/v1/me/top/tracks?limit=50&time_range={time_range}",
        headers={"Authorization": f"Bearer {token}"},
    )
    if result["status"] != 200:
        return []
    return [
        {
            "name": t["name"],
            "artist": ", ".join(art["name"] for art in t.get("artists", [])),
            "url": t["external_urls"].get("spotify", ""),
            "image": t["album"]["images"][0]["url"] if t.get("album", {}).get("images") else "",
            "album": t.get("album", {}).get("name", ""),
        }
        for t in result["body"].get("items", [])
    ]


def _fetch_recently_played(token):
    """Fetch user's recently played tracks."""
    result = _http_request(
        "https://api.spotify.com/v1/me/player/recently-played?limit=50",
        headers={"Authorization": f"Bearer {token}"},
    )
    if result["status"] != 200:
        return []
    return [
        {
            "name": item["track"]["name"],
            "artist": ", ".join(art["name"] for art in item["track"].get("artists", [])),
            "url": item["track"]["external_urls"].get("spotify", ""),
            "image": item["track"]["album"]["images"][0]["url"]
            if item["track"].get("album", {}).get("images")
            else "",
            "played_at": item.get("played_at", ""),
        }
        for item in result["body"].get("items", [])
    ]


def _derive_top_albums(tracks):
    """Derive top albums from top tracks by counting occurrences."""
    album_counts = {}
    for t in tracks:
        key = t.get("album", "")
        if not key:
            continue
        if key not in album_counts:
            album_counts[key] = {
                "name": key, "artist": t["artist"],
                "url": t["url"], "image": t["image"], "count": 0,
            }
        album_counts[key]["count"] += 1
    return sorted(album_counts.values(), key=lambda x: x["count"], reverse=True)[:20]


def _derive_top_genres(artists):
    """Derive top genres from top artists by counting genre occurrences."""
    genre_counts = {}
    genre_artists = {}
    for a in artists:
        for g in a.get("genres", []):
            genre_counts[g] = genre_counts.get(g, 0) + 1
            if g not in genre_artists:
                genre_artists[g] = []
            genre_artists[g].append(a["name"])
    sorted_genres = sorted(genre_counts.items(), key=lambda x: x[1], reverse=True)
    return [
        {"name": name, "count": count, "artists": genre_artists[name]}
        for name, count in sorted_genres[:20]
    ]


def _derive_frequent_listens(short_term_tracks):
    """Return short-term top tracks as 'frequent listens' (heavy rotation)."""
    for i, t in enumerate(short_term_tracks):
        t["play_count"] = len(short_term_tracks) - i
    return short_term_tracks[:20]


# ─── Response Helpers ────────────────────────────────────────────────────────
def _json_response(status, body, extra_headers=None):
    """Return a JSON API response."""
    h = {"Content-Type": "application/json", "Cache-Control": "no-store"}
    if extra_headers:
        h.update(extra_headers)
    return {"statusCode": status, "headers": h, "body": json.dumps(body)}


def _redirect(url, cookie=None):
    """Return a 302 redirect, optionally setting a cookie."""
    h = {"Location": url}
    resp = {"statusCode": 302, "headers": h, "body": ""}
    if cookie:
        resp["cookies"] = [cookie]
    return resp


# ─── Auth Event Helpers ──────────────────────────────────────────────────────
def _get_cookie_header(event):
    """Extract raw cookie string from API Gateway v2 event."""
    if event.get("cookies"):
        return "; ".join(event["cookies"])
    return event.get("headers", {}).get("cookie", "")


def _get_user_from_event(event):
    """Extract user_id from session cookie. Returns None if not authenticated."""
    cookies = _parse_cookies(_get_cookie_header(event))
    return _get_session(cookies.get("session_id"))


def _require_auth(event):
    """Return (user_id, None) or (None, 401_response)."""
    user_id = _get_user_from_event(event)
    if not user_id:
        return None, _json_response(401, {"error": "Not authenticated"})
    return user_id, None


# ─── Auth Route Handlers ────────────────────────────────────────────────────
def handle_login(event):
    """Start Spotify OAuth Authorization Code + PKCE flow."""
    client_id, _ = _get_spotify_app_credentials()
    state = secrets.token_urlsafe(32)
    verifier, challenge = _generate_pkce()

    _put_auth_state(state, verifier)

    params = urllib.parse.urlencode({
        "client_id": client_id,
        "response_type": "code",
        "redirect_uri": SPOTIFY_REDIRECT_URI,
        "scope": SPOTIFY_SCOPES,
        "state": state,
        "code_challenge_method": "S256",
        "code_challenge": challenge,
    })
    return _redirect(f"https://accounts.spotify.com/authorize?{params}")


def handle_callback(event):
    """Handle Spotify OAuth callback — exchange code for tokens, create session."""
    qs = event.get("queryStringParameters") or {}
    code = qs.get("code")
    state = qs.get("state")
    error = qs.get("error")

    if error:
        return _redirect(f"https://{WEBSITE_DOMAIN}/yourspotify/?error=access_denied")
    if not code or not state:
        return _redirect(f"https://{WEBSITE_DOMAIN}/yourspotify/?error=missing_params")

    # Validate state and get PKCE verifier (one-time use)
    verifier = _get_and_delete_auth_state(state)
    if not verifier:
        return _redirect(f"https://{WEBSITE_DOMAIN}/yourspotify/?error=invalid_state")

    # Exchange authorization code for tokens
    client_id, client_secret = _get_spotify_app_credentials()
    auth_b64 = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()

    result = _http_request(
        "https://accounts.spotify.com/api/token",
        headers={
            "Authorization": f"Basic {auth_b64}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        data={
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": SPOTIFY_REDIRECT_URI,
            "code_verifier": verifier,
        },
        method="POST",
    )
    if result["status"] != 200:
        return _redirect(f"https://{WEBSITE_DOMAIN}/yourspotify/?error=token_exchange_failed")

    tokens = result["body"]
    access_token = tokens["access_token"]
    refresh_token = tokens.get("refresh_token")
    if not refresh_token:
        return _redirect(f"https://{WEBSITE_DOMAIN}/yourspotify/?error=no_refresh_token")

    # Get Spotify user profile
    profile = _http_request(
        "https://api.spotify.com/v1/me",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    if profile["status"] != 200:
        return _redirect(f"https://{WEBSITE_DOMAIN}/yourspotify/?error=profile_failed")

    spotify_user_id = profile["body"]["id"]
    display_name = profile["body"].get("display_name", "")
    email = profile["body"].get("email", "")
    country = profile["body"].get("country", "")

    # Create/update user, encrypt and store refresh token
    user_id = _find_or_create_user(spotify_user_id, display_name, email, country)
    _store_encrypted_token(user_id, refresh_token)

    # Owner gets permanent session; regular users get standard session
    is_owner = _is_owner_spotify_id(spotify_user_id)
    max_age = OWNER_SESSION_MAX_AGE if is_owner else SESSION_MAX_AGE
    session_id = _create_session(user_id, max_age=max_age)
    cookie = _make_session_cookie(session_id, max_age=max_age)

    # Owner goes to My Spotify; regular users go to Your Spotify
    redirect_path = "/myspotify/" if is_owner else "/yourspotify/"
    return _redirect(f"https://{WEBSITE_DOMAIN}{redirect_path}", cookie)


def handle_logout(event):
    """Destroy session and clear cookie."""
    cookies = _parse_cookies(_get_cookie_header(event))
    _delete_session(cookies.get("session_id"))
    return _redirect(f"https://{WEBSITE_DOMAIN}/yourspotify/", _clear_session_cookie())


def handle_auth_status(event):
    """Check if user is logged in. Returns profile info, owner flag, policy status."""
    user_id = _get_user_from_event(event)
    if not user_id:
        return _json_response(200, {"logged_in": False})

    table = _get_dynamodb().Table(USERS_TABLE)
    resp = table.get_item(Key={"user_id": user_id})
    user = resp.get("Item", {})
    is_owner = _is_owner_user_id(user_id)

    # Check if privacy policy has been updated since user last acknowledged
    user_policy = user.get("policy_acknowledged", "")
    policy_updated = bool(user_policy and user_policy != POLICY_VERSION)

    return _json_response(200, {
        "logged_in": True,
        "display_name": user.get("display_name", ""),
        "is_owner": is_owner,
        "policy_updated": policy_updated,
        "policy_version": POLICY_VERSION,
    })


def handle_acknowledge_policy(event):
    """User acknowledges updated privacy policy."""
    user_id, err = _require_auth(event)
    if err:
        return err
    table = _get_dynamodb().Table(USERS_TABLE)
    table.update_item(
        Key={"user_id": user_id},
        UpdateExpression="SET policy_acknowledged = :pv, updated_at = :ua",
        ExpressionAttributeValues={":pv": POLICY_VERSION, ":ua": int(time.time())},
    )
    return _json_response(200, {"message": "Policy acknowledged", "policy_version": POLICY_VERSION})


# ─── Data Route Handlers ────────────────────────────────────────────────────
def handle_new_releases(event):
    """Fetch new releases (public data, no auth required)."""
    try:
        client_id, client_secret = _get_spotify_app_credentials()
        token = _get_client_token(client_id, client_secret)
        releases = _fetch_new_releases(token)
        return _json_response(200, {"albums": releases})
    except Exception as e:
        return _json_response(500, {"error": str(e)})


def _handle_user_insight(event, insight_type, fetch_fn):
    """Generic handler for user-scoped cached insights."""
    user_id, err = _require_auth(event)
    if err:
        return err
    try:
        cached = _get_cached_insight(user_id, insight_type)
        if cached:
            return _json_response(200, cached)

        token = _get_user_access_token(user_id)
        if not token:
            return _json_response(401, {"error": "Spotify account not connected"})

        data = fetch_fn(token)
        _cache_insight(user_id, insight_type, data)
        return _json_response(200, data)
    except Exception as e:
        return _json_response(500, {"error": str(e)})


def handle_top_artists(event):
    return _handle_user_insight(event, "top_artists",
                                lambda t: {"artists": _fetch_top_artists(t)})


def handle_top_albums(event):
    return _handle_user_insight(event, "top_albums",
                                lambda t: {"albums": _derive_top_albums(_fetch_top_tracks(t, "medium_term"))})


def handle_recent_listens(event):
    return _handle_user_insight(event, "recent_listens",
                                lambda t: {"tracks": _fetch_recently_played(t)})


def handle_top_genres(event):
    return _handle_user_insight(event, "top_genres",
                                lambda t: {"genres": _derive_top_genres(_fetch_top_artists(t))})


def handle_frequent_listens(event):
    return _handle_user_insight(event, "frequent_listens",
                                lambda t: {"tracks": _derive_frequent_listens(_fetch_top_tracks(t, "short_term"))})


# ─── Owner Data Route Handlers ───────────────────────────────────────────────
def _handle_owner_insight(event, insight_type, fetch_fn):
    """Generic handler for owner's public data (no visitor auth needed)."""
    user_id = _get_owner_user_id()
    if not user_id:
        return _json_response(503, {"error": "Owner account not configured"})
    try:
        cache_key = f"owner_{insight_type}"
        cached = _get_cached_insight(user_id, cache_key)
        if cached:
            return _json_response(200, cached)

        token = _get_user_access_token(user_id)
        if not token:
            return _json_response(503, {"error": "Owner Spotify not connected"})

        data = fetch_fn(token)
        _cache_insight(user_id, cache_key, data)
        return _json_response(200, data)
    except Exception as e:
        return _json_response(500, {"error": str(e)})


def handle_owner_top_artists(event):
    return _handle_owner_insight(event, "top_artists",
                                 lambda t: {"artists": _fetch_top_artists(t)})


def handle_owner_top_albums(event):
    return _handle_owner_insight(event, "top_albums",
                                 lambda t: {"albums": _derive_top_albums(_fetch_top_tracks(t, "medium_term"))})


def handle_owner_recent_listens(event):
    return _handle_owner_insight(event, "recent_listens",
                                 lambda t: {"tracks": _fetch_recently_played(t)})


def handle_owner_top_genres(event):
    return _handle_owner_insight(event, "top_genres",
                                 lambda t: {"genres": _derive_top_genres(_fetch_top_artists(t))})


def handle_owner_frequent_listens(event):
    return _handle_owner_insight(event, "frequent_listens",
                                 lambda t: {"tracks": _derive_frequent_listens(_fetch_top_tracks(t, "short_term"))})


def handle_delete_data(event):
    """Delete all user data (CCPA / ICDPA compliance). Owner cannot delete."""
    user_id, err = _require_auth(event)
    if err:
        return err
    # Prevent owner from accidentally deleting their account
    if _is_owner_user_id(user_id):
        return _json_response(403, {"error": "Owner account cannot be deleted via this endpoint"})
    try:
        db = _get_dynamodb()
        # Delete tokens
        db.Table(TOKENS_TABLE).delete_item(Key={"user_id": user_id})
        # Delete all cached insights
        insights_table = db.Table(INSIGHTS_TABLE)
        resp = insights_table.query(KeyConditionExpression=Key("user_id").eq(user_id))
        for item in resp.get("Items", []):
            insights_table.delete_item(Key={"user_id": user_id, "insight_key": item["insight_key"]})
        # Delete user record
        db.Table(USERS_TABLE).delete_item(Key={"user_id": user_id})
        # Delete session
        cookies = _parse_cookies(_get_cookie_header(event))
        _delete_session(cookies.get("session_id"))

        return _json_response(200,
                              {"message": "All your data has been deleted."},
                              {"Set-Cookie": _clear_session_cookie()})
    except Exception as e:
        return _json_response(500, {"error": str(e)})


# ─── Access Request Handlers ─────────────────────────────────────────────────
def handle_submit_access_request(event):
    """Submit an access request (public, no auth required)."""
    try:
        body = json.loads(event.get("body") or "{}")
    except (json.JSONDecodeError, TypeError):
        return _json_response(400, {"error": "Invalid JSON body"})

    full_name = (body.get("full_name") or "").strip()
    spotify_email = (body.get("spotify_email") or "").strip()
    country = (body.get("country") or "").strip()

    if not full_name or not spotify_email or not country:
        return _json_response(400, {"error": "full_name, spotify_email, and country are required"})

    # Basic email validation
    if "@" not in spotify_email or "." not in spotify_email:
        return _json_response(400, {"error": "Invalid email address"})

    request_id = str(uuid.uuid4())
    now = int(time.time())

    table = _get_dynamodb().Table(ACCESS_REQUESTS_TABLE)
    table.put_item(Item={
        "request_id": request_id,
        "full_name": full_name,
        "spotify_email": spotify_email,
        "country": country,
        "status": "pending",
        "requested_at": now,
    })

    # Notify admin via email
    if ADMIN_EMAIL:
        _send_email(
            ADMIN_EMAIL,
            f"New Spotify Demo Access Request from {full_name}",
            f"""<h2>New Access Request</h2>
            <p><strong>Name:</strong> {full_name}</p>
            <p><strong>Spotify Email:</strong> {spotify_email}</p>
            <p><strong>Country:</strong> {country}</p>
            <p><strong>Request ID:</strong> {request_id}</p>
            <p>Log in to admin panel to approve or reject.</p>""",
        )

    return _json_response(201, {"message": "Access request submitted", "request_id": request_id})


def handle_access_request_count(event):
    """Return count of total and approved access requests (public)."""
    table = _get_dynamodb().Table(ACCESS_REQUESTS_TABLE)
    try:
        # Scan for total count (small table, acceptable)
        total_resp = table.scan(Select="COUNT")
        total = total_resp.get("Count", 0)

        # Query approved count via GSI
        approved_resp = table.query(
            IndexName="status-index",
            KeyConditionExpression=Key("status").eq("approved"),
            Select="COUNT",
        )
        approved = approved_resp.get("Count", 0)

        # Get country breakdown from all requests
        all_resp = table.scan(ProjectionExpression="country")
        country_counts = {}
        for item in all_resp.get("Items", []):
            c = item.get("country", "Unknown")
            country_counts[c] = country_counts.get(c, 0) + 1
        top_countries = sorted(country_counts.items(), key=lambda x: x[1], reverse=True)[:10]

        return _json_response(200, {
            "total_requests": total,
            "approved_count": approved,
            "countries": [{"country": c, "count": n} for c, n in top_countries],
        })
    except Exception as e:
        return _json_response(500, {"error": str(e)})


# ─── Admin Handlers (Owner Only) ────────────────────────────────────────────
def handle_admin_list_requests(event):
    """List pending access requests (owner only)."""
    user_id, err = _require_auth(event)
    if err:
        return err
    if not _is_owner_user_id(user_id):
        return _json_response(403, {"error": "Admin access required"})

    table = _get_dynamodb().Table(ACCESS_REQUESTS_TABLE)
    try:
        # Get all requests (small table)
        resp = table.scan()
        items = resp.get("Items", [])
        # Sort by requested_at descending
        items.sort(key=lambda x: x.get("requested_at", 0), reverse=True)
        # Convert Decimal to int for JSON serialization
        for item in items:
            for k, v in item.items():
                if hasattr(v, "__int__"):
                    item[k] = int(v)
        return _json_response(200, {"requests": items})
    except Exception as e:
        return _json_response(500, {"error": str(e)})


def handle_admin_approve_request(event):
    """Approve an access request and notify user (owner only)."""
    user_id, err = _require_auth(event)
    if err:
        return err
    if not _is_owner_user_id(user_id):
        return _json_response(403, {"error": "Admin access required"})

    try:
        body = json.loads(event.get("body") or "{}")
    except (json.JSONDecodeError, TypeError):
        return _json_response(400, {"error": "Invalid JSON body"})

    request_id = body.get("request_id")
    if not request_id:
        return _json_response(400, {"error": "request_id is required"})

    table = _get_dynamodb().Table(ACCESS_REQUESTS_TABLE)
    resp = table.get_item(Key={"request_id": request_id})
    item = resp.get("Item")
    if not item:
        return _json_response(404, {"error": "Request not found"})

    now = int(time.time())
    table.update_item(
        Key={"request_id": request_id},
        UpdateExpression="SET #s = :s, approved_at = :aa",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":s": "approved", ":aa": now},
    )

    # Send approval email to user
    user_email = item.get("spotify_email", "")
    user_name = item.get("full_name", "User")
    if user_email:
        _send_email(
            user_email,
            "Your Spotify Demo Access Has Been Approved!",
            f"""<h2>Welcome, {user_name}!</h2>
            <p>Your request to access the Spotify Demo on
            <a href="https://{WEBSITE_DOMAIN}/yourspotify/">babasanmiadeyemi.com</a>
            has been approved.</p>
            <p>You can now log in with your Spotify account to explore your personal
            listening data, discover curated playlists, and more.</p>
            <p>Visit <a href="https://{WEBSITE_DOMAIN}/yourspotify/">Your Spotify</a> to get started!</p>
            <br><p>Best regards,<br>Babasanmi Adeyemi</p>""",
        )

    return _json_response(200, {"message": "Request approved", "request_id": request_id})


def handle_admin_reject_request(event):
    """Reject an access request (owner only)."""
    user_id, err = _require_auth(event)
    if err:
        return err
    if not _is_owner_user_id(user_id):
        return _json_response(403, {"error": "Admin access required"})

    try:
        body = json.loads(event.get("body") or "{}")
    except (json.JSONDecodeError, TypeError):
        return _json_response(400, {"error": "Invalid JSON body"})

    request_id = body.get("request_id")
    if not request_id:
        return _json_response(400, {"error": "request_id is required"})

    table = _get_dynamodb().Table(ACCESS_REQUESTS_TABLE)
    resp = table.get_item(Key={"request_id": request_id})
    if not resp.get("Item"):
        return _json_response(404, {"error": "Request not found"})

    table.update_item(
        Key={"request_id": request_id},
        UpdateExpression="SET #s = :s, rejected_at = :ra",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":s": "rejected", ":ra": int(time.time())},
    )

    return _json_response(200, {"message": "Request rejected", "request_id": request_id})


# ─── Country Stats Handler ───────────────────────────────────────────────────
def handle_country_stats(event):
    """Aggregate music stats by country from user profiles (public)."""
    try:
        # Get all users with country info
        users_table = _get_dynamodb().Table(USERS_TABLE)
        resp = users_table.scan(ProjectionExpression="user_id, country")
        users = resp.get("Items", [])

        # Get cached insights for each user with a country
        insights_table = _get_dynamodb().Table(INSIGHTS_TABLE)
        country_genres = {}

        for user in users:
            country = user.get("country")
            if not country:
                continue
            if country not in country_genres:
                country_genres[country] = {}
            # Try to get cached top_genres insight for this user
            insight_resp = insights_table.get_item(
                Key={"user_id": user["user_id"], "insight_key": "top_genres"}
            )
            insight = insight_resp.get("Item")
            if insight and insight.get("expires_at", 0) >= int(time.time()):
                genres_data = json.loads(insight.get("data", "{}"))
                for genre in genres_data.get("genres", []):
                    name = genre.get("name", "")
                    count = genre.get("count", 1)
                    country_genres[country][name] = country_genres[country].get(name, 0) + count

        # Build response
        stats = []
        for country, genres in country_genres.items():
            top = sorted(genres.items(), key=lambda x: x[1], reverse=True)[:5]
            stats.append({
                "country": country,
                "user_count": sum(1 for u in users if u.get("country") == country),
                "top_genres": [{"name": g, "count": c} for g, c in top],
            })
        stats.sort(key=lambda x: x["user_count"], reverse=True)

        return _json_response(200, {"country_stats": stats})
    except Exception as e:
        return _json_response(500, {"error": str(e)})


# ─── Playlist Engine ─────────────────────────────────────────────────────────

# Maps user-facing timeframe to parameters
TIMEFRAME_CONFIG = {
    "2w": {"days": 14, "label": "2 Weeks", "spotify_time_range": "short_term"},
    "1m": {"days": 30, "label": "1 Month", "spotify_time_range": "short_term"},
    "3m": {"days": 90, "label": "3 Months", "spotify_time_range": "medium_term"},
}

PLAY_HISTORY_TTL_DAYS = 95  # Slightly more than 3 months

# Spotify recently-played endpoint returns max 50 items (no time filtering)
SPOTIFY_RECENTLY_PLAYED_MAX = 50

PLAYLIST_THEMES = [
    {
        "id": "essentials",
        "name": "Your Essentials",
        "description": "A mix built from your top artists and tracks",
        "default_params": {"limit": 20},
        "seed_type": "taste",
    },
    {
        "id": "hidden_gems",
        "name": "Hidden Gems",
        "description": "Popular tracks you haven't discovered yet in your genres",
        "default_params": {"limit": 40, "min_popularity": 70},
        "seed_type": "genres",
    },
    {
        "id": "energy_boost",
        "name": "Energy Boost",
        "description": "High-energy bangers to power your day",
        "default_params": {"limit": 40, "target_energy": 0.9, "target_danceability": 0.8, "min_tempo": 120},
        "seed_type": "genres",
    },
    {
        "id": "chill_mode",
        "name": "Chill Mode",
        "description": "Laid-back vibes for relaxation",
        "default_params": {"limit": 40, "target_energy": 0.3, "target_acousticness": 0.7, "max_tempo": 105},
        "seed_type": "genres",
    },
    {
        "id": "discovery_mix",
        "name": "Discovery Mix",
        "description": "Explore new genres outside your comfort zone",
        "default_params": {"limit": 40, "min_popularity": 70},
        "seed_type": "discovery",
    },
]

PLAYLIST_CACHE_TTL = 259200  # 72 hours (3 days)

DEFAULT_PLAYLIST_PREFERENCES = {
    "timeframe": "1m",
    "exclude_listened": True,
    "genres": [],
    "discovery_genres": [],
    "excluded_genres": [],
}


def _parse_played_at(played_at):
    """Parse a Spotify ISO 8601 timestamp to epoch milliseconds."""
    base = played_at.split(".")[0]
    t = time.strptime(base, "%Y-%m-%dT%H:%M:%S")
    epoch_ms = int(calendar.timegm(t) * 1000)
    if "." in played_at:
        frac = played_at.split(".")[1].rstrip("Z")
        epoch_ms += int(frac[:3].ljust(3, "0"))
    return epoch_ms


def _record_recent_plays(user_id, token):
    """Fetch recently-played tracks from Spotify, enrich with genres, store in DynamoDB.

    This is the H(T) accumulation mechanism — each call captures up to 50
    recent plays and persists them with a TTL slightly beyond the longest
    supported timeframe window (95 days).
    """
    result = _http_request(
        "https://api.spotify.com/v1/me/player/recently-played?limit=50",
        headers={"Authorization": f"Bearer {token}"},
    )
    if result["status"] != 200:
        return 0

    items = result["body"].get("items", [])
    if not items:
        return 0

    # Extract unique artist IDs across all tracks
    artist_ids_seen = set()
    for item in items:
        for artist in item.get("track", {}).get("artists", []):
            aid = artist.get("id")
            if aid:
                artist_ids_seen.add(aid)

    # Batch-fetch artist details for genre data (max 50 per request)
    genre_map = {}
    artist_id_list = list(artist_ids_seen)
    for i in range(0, len(artist_id_list), 50):
        batch_ids = artist_id_list[i:i + 50]
        ids_param = ",".join(batch_ids)
        artist_resp = _http_request(
            f"https://api.spotify.com/v1/artists?ids={ids_param}",
            headers={"Authorization": f"Bearer {token}"},
        )
        if artist_resp["status"] == 200:
            for artist in artist_resp["body"].get("artists", []):
                if artist and artist.get("id"):
                    genre_map[artist["id"]] = artist.get("genres", [])

    # Write each play event to DynamoDB
    table = _get_dynamodb().Table(PLAY_HISTORY_TABLE)
    count = 0
    now_epoch = int(time.time())
    expires_at = now_epoch + (PLAY_HISTORY_TTL_DAYS * 86400)

    with table.batch_writer() as batch:
        for item in items:
            track = item.get("track")
            played_at_str = item.get("played_at", "")
            if not track or not played_at_str:
                continue

            try:
                epoch_ms = _parse_played_at(played_at_str)
            except (ValueError, IndexError):
                continue

            track_genres = set()
            track_artist_ids = []
            for artist in track.get("artists", []):
                aid = artist.get("id")
                if aid:
                    track_artist_ids.append(aid)
                    track_genres.update(genre_map.get(aid, []))

            record = {
                "user_id": user_id,
                "played_at": epoch_ms,
                "track_id": track.get("id", ""),
                "track_name": track.get("name", ""),
                "artist_name": ", ".join(a.get("name", "") for a in track.get("artists", [])),
                "artist_ids": track_artist_ids,
                "genres": sorted(track_genres),
                "album_name": track.get("album", {}).get("name", ""),
                "image_url": (
                    track["album"]["images"][0]["url"]
                    if track.get("album", {}).get("images")
                    else ""
                ),
                "uri": track.get("uri", ""),
                "spotify_url": track.get("external_urls", {}).get("spotify", ""),
                "expires_at": expires_at,
            }
            batch.put_item(Item=record)
            count += 1

    return count


def _build_play_history(user_id, timeframe):
    """Query DynamoDB play-history for the user's plays within timeframe T."""
    config = TIMEFRAME_CONFIG.get(timeframe)
    if not config:
        return []

    cutoff_ms = (int(time.time()) - config["days"] * 86400) * 1000

    table = _get_dynamodb().Table(PLAY_HISTORY_TABLE)
    plays = []
    kwargs = {
        "KeyConditionExpression": Key("user_id").eq(user_id) & Key("played_at").gte(cutoff_ms),
    }

    while True:
        resp = table.query(**kwargs)
        plays.extend(resp.get("Items", []))
        last_key = resp.get("LastEvaluatedKey")
        if not last_key:
            break
        kwargs["ExclusiveStartKey"] = last_key

    return plays


def _build_spotify_supplement(token, timeframe):
    """Fetch Spotify's supplementary data when H(T) is insufficient.

    Retrieves recently-played, top tracks, and top artists from Spotify,
    then enriches tracks with genre data from the top artists response.
    """
    config = TIMEFRAME_CONFIG.get(timeframe, TIMEFRAME_CONFIG["1m"])
    spotify_range = config["spotify_time_range"]

    # Recently played (raw)
    recent_resp = _http_request(
        "https://api.spotify.com/v1/me/player/recently-played?limit=50",
        headers={"Authorization": f"Bearer {token}"},
    )
    recent_tracks = []
    if recent_resp["status"] == 200:
        for item in recent_resp["body"].get("items", []):
            track = item.get("track", {})
            recent_tracks.append({
                "track_id": track.get("id", ""),
                "track_name": track.get("name", ""),
                "artist_name": ", ".join(a.get("name", "") for a in track.get("artists", [])),
                "artist_ids": [a.get("id", "") for a in track.get("artists", []) if a.get("id")],
                "genres": [],
            })

    # Top tracks
    top_tracks_resp = _http_request(
        f"https://api.spotify.com/v1/me/top/tracks?limit=50&time_range={spotify_range}",
        headers={"Authorization": f"Bearer {token}"},
    )
    top_tracks = []
    if top_tracks_resp["status"] == 200:
        for t in top_tracks_resp["body"].get("items", []):
            top_tracks.append({
                "track_id": t.get("id", ""),
                "track_name": t.get("name", ""),
                "artist_name": ", ".join(a.get("name", "") for a in t.get("artists", [])),
                "artist_ids": [a.get("id", "") for a in t.get("artists", []) if a.get("id")],
                "genres": [],
            })

    # Top artists
    top_artists_resp = _http_request(
        f"https://api.spotify.com/v1/me/top/artists?limit=50&time_range={spotify_range}",
        headers={"Authorization": f"Bearer {token}"},
    )
    artists = []
    genres_map = {}
    if top_artists_resp["status"] == 200:
        for a in top_artists_resp["body"].get("items", []):
            aid = a.get("id", "")
            genres = a.get("genres", [])
            artists.append({
                "artist_id": aid,
                "artist_name": a.get("name", ""),
                "genres": genres,
            })
            if aid:
                genres_map[aid] = genres

    # Enrich tracks with genres from their artists
    all_tracks = recent_tracks + top_tracks
    for track in all_tracks:
        track_genres = set()
        for aid in track.get("artist_ids", []):
            track_genres.update(genres_map.get(aid, []))
        track["genres"] = sorted(track_genres)

    return {"tracks": all_tracks, "artists": artists, "genres_map": genres_map}


def _compute_taste_stats(plays):
    """Compute frequency statistics from a list of play items.

    Returns dict with: N, U_tracks, U_genres, top_track_ids, top_artist_ids,
    genre_counts, track_ids_set.
    """
    n = len(plays)
    track_freq = {}
    artist_freq = {}
    genre_freq = {}
    all_track_ids = set()

    for play in plays:
        tid = play.get("track_id", "")
        if tid:
            track_freq[tid] = track_freq.get(tid, 0) + 1
            all_track_ids.add(tid)

        for aid in play.get("artist_ids", []):
            if aid:
                artist_freq[aid] = artist_freq.get(aid, 0) + 1

        for genre in play.get("genres", []):
            if genre:
                genre_freq[genre] = genre_freq.get(genre, 0) + 1

    top_tracks = sorted(track_freq.items(), key=lambda x: x[1], reverse=True)[:20]
    top_artists = sorted(artist_freq.items(), key=lambda x: x[1], reverse=True)[:20]

    return {
        "N": n,
        "U_tracks": len(all_track_ids),
        "U_genres": len(genre_freq),
        "top_track_ids": top_tracks,
        "top_artist_ids": top_artists,
        "genre_counts": genre_freq,
        "track_ids_set": all_track_ids,
    }


def _should_supplement(stats, playlist_id, selected_genres_count):
    """Determine whether Spotify supplement data is needed.

    Uses dynamic thresholds based on play-history richness.
    """
    if playlist_id == "essentials":
        h_threshold = max(60, int(2.5 * stats["U_tracks"]))
        if stats["N"] < h_threshold or stats["U_tracks"] < 25:
            return True
        return False

    # Playlists 2-5: genre-based thresholds
    g = selected_genres_count
    capped_g = min(15, max(8, g))
    h_threshold = max(80, 10 * capped_g)
    if stats["N"] < h_threshold or stats["U_genres"] < 8:
        return True
    return False


def _build_exclusion_set(plays, spotify_recent_tracks):
    """Build a set of track IDs to exclude from recommendations."""
    excluded = set()
    for p in plays:
        tid = p.get("track_id")
        if tid:
            excluded.add(tid)
    for t in spotify_recent_tracks:
        tid = t.get("track_id")
        if tid:
            excluded.add(tid)
    return excluded


def _merge_plays_with_supplement(h_plays, supplement_data):
    """Merge app-recorded plays H(T) with Spotify supplement data.

    H(T) items take priority — supplement only adds tracks not already present.
    """
    seen_track_ids = set()
    merged = []

    for play in h_plays:
        tid = play.get("track_id", "")
        merged.append({
            "track_id": tid,
            "track_name": play.get("track_name", ""),
            "artist_name": play.get("artist_name", ""),
            "artist_ids": play.get("artist_ids", []),
            "genres": play.get("genres", []),
        })
        if tid:
            seen_track_ids.add(tid)

    for track in supplement_data.get("tracks", []):
        tid = track.get("track_id", "")
        if tid and tid not in seen_track_ids:
            merged.append({
                "track_id": tid,
                "track_name": track.get("track_name", ""),
                "artist_name": track.get("artist_name", ""),
                "artist_ids": track.get("artist_ids", []),
                "genres": track.get("genres", []),
            })
            seen_track_ids.add(tid)

    return merged


def _get_user_playlist_preferences(user_id):
    """Get the user's saved playlist preferences from the users table."""
    table = _get_dynamodb().Table(USERS_TABLE)
    resp = table.get_item(Key={"user_id": user_id})
    item = resp.get("Item")
    if not item:
        return dict(DEFAULT_PLAYLIST_PREFERENCES)

    stored = item.get("playlist_preferences", {})
    if not stored or not isinstance(stored, dict):
        return dict(DEFAULT_PLAYLIST_PREFERENCES)

    prefs = dict(DEFAULT_PLAYLIST_PREFERENCES)
    prefs.update(stored)

    if prefs["timeframe"] not in TIMEFRAME_CONFIG:
        prefs["timeframe"] = "1m"
    for list_key in ("genres", "discovery_genres", "excluded_genres"):
        if not isinstance(prefs.get(list_key), list):
            prefs[list_key] = []
    if not isinstance(prefs.get("exclude_listened"), bool):
        prefs["exclude_listened"] = True

    return prefs


def _save_user_playlist_preferences(user_id, prefs):
    """Validate and persist playlist preferences to the users table."""
    if prefs.get("timeframe") not in TIMEFRAME_CONFIG:
        raise ValueError(f"Invalid timeframe: {prefs.get('timeframe')}. "
                         f"Must be one of {list(TIMEFRAME_CONFIG.keys())}")

    for key in ("genres", "discovery_genres"):
        val = prefs.get(key, [])
        if not isinstance(val, list):
            raise ValueError(f"{key} must be a list")
        if len(val) > 15:
            raise ValueError(f"{key} must have at most 15 items")

    table = _get_dynamodb().Table(USERS_TABLE)
    now = int(time.time())
    table.update_item(
        Key={"user_id": user_id},
        UpdateExpression="SET playlist_preferences = :pp, updated_at = :ua",
        ExpressionAttributeValues={
            ":pp": prefs,
            ":ua": now,
        },
    )


def _fetch_available_genre_seeds(token):
    """Fetch the list of valid genre seeds from Spotify."""
    resp = _http_request(
        "https://api.spotify.com/v1/recommendations/available-genre-seeds",
        headers={"Authorization": f"Bearer {token}"},
    )
    if resp["status"] == 200:
        return sorted(resp["body"].get("genres", []))
    return []


def _filter_exclusions(tracks, exclusion_set):
    """Remove recommended tracks whose ID is in the exclusion set."""
    if not exclusion_set:
        return tracks

    filtered = []
    for t in tracks:
        tid = ""
        uri = t.get("uri", "")
        if uri and uri.startswith("spotify:track:"):
            tid = uri.split(":")[-1]
        elif t.get("url"):
            parts = t["url"].rstrip("/").split("/")
            if parts:
                tid = parts[-1].split("?")[0]

        if tid and tid in exclusion_set:
            continue
        filtered.append(t)
    return filtered


def _fetch_recommendations(token, seed_artists=None, seed_tracks=None,
                            seed_genres=None, **params):
    """Fetch recommendations from Spotify API."""
    query_params = {k: v for k, v in params.items() if v is not None}
    if seed_artists:
        query_params["seed_artists"] = ",".join(seed_artists[:5])
    if seed_tracks:
        query_params["seed_tracks"] = ",".join(seed_tracks[:5])
    if seed_genres:
        query_params["seed_genres"] = ",".join(seed_genres[:5])

    # Total seeds must not exceed 5
    total_seeds = len(seed_artists or []) + len(seed_tracks or []) + len(seed_genres or [])
    if total_seeds == 0:
        return []

    qs = urllib.parse.urlencode(query_params)
    result = _http_request(
        f"https://api.spotify.com/v1/recommendations?{qs}",
        headers={"Authorization": f"Bearer {token}"},
    )
    if result["status"] != 200:
        return []

    return [
        {
            "name": t["name"],
            "artist": ", ".join(art["name"] for art in t.get("artists", [])),
            "url": t["external_urls"].get("spotify", ""),
            "uri": t.get("uri", ""),
            "image": t["album"]["images"][0]["url"] if t.get("album", {}).get("images") else "",
            "album": t.get("album", {}).get("name", ""),
            "preview_url": t.get("preview_url"),
        }
        for t in result["body"].get("tracks", [])
    ]


def handle_playlist_suggestions(event):
    """Generate 5 curated playlists using play-history H(T), Spotify supplement,
    user preferences, and exclusion filtering.

    Supports ?force=true to bypass cache.
    """
    user_id, err = _require_auth(event)
    if err:
        return err

    # Check for force-refresh query param
    qs = event.get("queryStringParameters") or {}
    force = qs.get("force", "").lower() == "true"

    if not force:
        cached = _get_cached_insight(user_id, "playlist_suggestions")
        if cached:
            return _json_response(200, cached)

    try:
        token = _get_user_access_token(user_id)
        if not token:
            return _json_response(401, {"error": "Spotify account not connected"})

        # Load user preferences
        prefs = _get_user_playlist_preferences(user_id)
        timeframe = prefs["timeframe"]
        exclude_listened = prefs["exclude_listened"]
        user_genres = prefs.get("genres", [])
        discovery_genres = prefs.get("discovery_genres", [])
        excluded_genres_pref = prefs.get("excluded_genres", [])

        # Side effect: accumulate recent plays into H(T)
        _record_recent_plays(user_id, token)

        # Build play history from DynamoDB
        h_plays = _build_play_history(user_id, timeframe)

        # Compute taste stats from H(T)
        h_stats = _compute_taste_stats(h_plays)

        # Fetch Spotify supplement (always fetch; used for exclusion + fallback)
        supplement_data = _build_spotify_supplement(token, timeframe)

        # Build exclusion set
        exclusion_set = set()
        if exclude_listened:
            exclusion_set = _build_exclusion_set(h_plays, supplement_data["tracks"])

        # Get available genre seeds from Spotify
        available_genres = _fetch_available_genre_seeds(token)
        available_genres_set = set(available_genres)

        # Validate user-selected genres
        valid_user_genres = [g for g in user_genres if g in available_genres_set]
        valid_discovery_genres = [g for g in discovery_genres if g in available_genres_set]
        excluded_genres_set = set(excluded_genres_pref)

        # Pre-compute merged stats lazily in case any playlist needs supplement
        merged_plays = None
        merged_stats = None

        def _get_merged():
            nonlocal merged_plays, merged_stats
            if merged_plays is None:
                merged_plays = _merge_plays_with_supplement(h_plays, supplement_data)
                merged_stats = _compute_taste_stats(merged_plays)
            return merged_stats

        playlists = []
        for theme in PLAYLIST_THEMES:
            pid = theme["id"]
            params = dict(theme["default_params"])
            seeds_a, seeds_t, seeds_g = [], [], []

            if pid == "essentials":
                genre_count = len(valid_user_genres)
                if _should_supplement(h_stats, pid, genre_count):
                    stats = _get_merged()
                else:
                    stats = h_stats

                # Seeds: top artists[:3] + top tracks[:2] (max 5 total)
                if excluded_genres_set and stats["top_artist_ids"]:
                    artist_genre_map = supplement_data.get("genres_map", {})
                    filtered_artists = []
                    for aid, _count in stats["top_artist_ids"]:
                        artist_genres = set(artist_genre_map.get(aid, []))
                        if not artist_genres.intersection(excluded_genres_set):
                            filtered_artists.append(aid)
                        if len(filtered_artists) >= 3:
                            break
                    seeds_a = filtered_artists[:3]
                else:
                    seeds_a = [aid for aid, _ in stats["top_artist_ids"][:3]]

                seeds_t = [tid for tid, _ in stats["top_track_ids"][:2]]
                total = len(seeds_a) + len(seeds_t)
                if total > 5:
                    seeds_t = seeds_t[:max(0, 5 - len(seeds_a))]

            elif pid in ("hidden_gems", "energy_boost", "chill_mode"):
                genre_count = len(valid_user_genres)
                if _should_supplement(h_stats, pid, genre_count):
                    stats = _get_merged()
                else:
                    stats = h_stats

                if valid_user_genres:
                    seeds_g = valid_user_genres[:5]
                else:
                    top_genres_from_stats = sorted(
                        stats["genre_counts"].items(), key=lambda x: x[1], reverse=True
                    )
                    seeds_g = [
                        g for g, _ in top_genres_from_stats
                        if g in available_genres_set
                    ][:5]

                if not seeds_g:
                    seeds_a = [aid for aid, _ in stats["top_artist_ids"][:5]]

            elif pid == "discovery_mix":
                genre_count = len(valid_discovery_genres)
                if _should_supplement(h_stats, pid, genre_count):
                    stats = _get_merged()
                else:
                    stats = h_stats

                user_genre_set = set(stats["genre_counts"].keys())
                if valid_discovery_genres:
                    seeds_g = valid_discovery_genres[:5]
                else:
                    seeds_g = [
                        g for g in available_genres
                        if g not in user_genre_set
                    ][:5]
                if not seeds_g:
                    seeds_g = available_genres[:5]

            # Skip if no seeds at all
            if not seeds_a and not seeds_t and not seeds_g:
                playlists.append({
                    "id": pid,
                    "name": theme["name"],
                    "description": theme["description"],
                    "tracks": [],
                    "message": "Not enough data to generate this playlist",
                })
                continue

            tracks = _fetch_recommendations(
                token,
                seed_artists=seeds_a or None,
                seed_tracks=seeds_t or None,
                seed_genres=seeds_g or None,
                **params,
            )

            if exclude_listened and exclusion_set:
                tracks = _filter_exclusions(tracks, exclusion_set)

            tracks = tracks[:20]

            playlists.append({
                "id": pid,
                "name": theme["name"],
                "description": theme["description"],
                "tracks": tracks,
            })

        result = {
            "playlists": playlists,
            "preferences": prefs,
            "stats": {
                "total_plays": h_stats["N"],
                "unique_tracks": h_stats["U_tracks"],
                "unique_genres": h_stats["U_genres"],
                "timeframe": timeframe,
                "timeframe_label": TIMEFRAME_CONFIG[timeframe]["label"],
                "supplemented": merged_stats is not None,
            },
        }

        # Cache for 72 hours
        table = _get_dynamodb().Table(INSIGHTS_TABLE)
        now = int(time.time())
        table.put_item(Item={
            "user_id": user_id,
            "insight_key": "playlist_suggestions",
            "data": json.dumps(result),
            "created_at": now,
            "expires_at": now + PLAYLIST_CACHE_TTL,
        })

        return _json_response(200, result)

    except Exception as e:
        return _json_response(500, {"error": str(e)})


def handle_save_playlist(event):
    """Save a curated playlist to the user's Spotify account."""
    user_id, err = _require_auth(event)
    if err:
        return err

    try:
        body = json.loads(event.get("body") or "{}")
    except (json.JSONDecodeError, TypeError):
        return _json_response(400, {"error": "Invalid JSON body"})

    playlist_name = body.get("playlist_name", "").strip()
    track_uris = body.get("track_uris", [])
    description = body.get("description", "").strip()

    if not playlist_name:
        return _json_response(400, {"error": "playlist_name is required"})
    if not track_uris or not isinstance(track_uris, list):
        return _json_response(400, {"error": "track_uris must be a non-empty list"})

    try:
        token = _get_user_access_token(user_id)
        if not token:
            return _json_response(401, {"error": "Spotify account not connected"})

        # Get user's Spotify ID
        profile = _http_request(
            "https://api.spotify.com/v1/me",
            headers={"Authorization": f"Bearer {token}"},
        )
        if profile["status"] != 200:
            return _json_response(500, {"error": "Could not fetch Spotify profile"})

        spotify_user_id = profile["body"]["id"]

        # Create the playlist
        create_result = _http_request(
            f"https://api.spotify.com/v1/users/{spotify_user_id}/playlists",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            data=json.dumps({
                "name": playlist_name,
                "description": description or f"Curated by babasanmiadeyemi.com",
                "public": True,
            }).encode("utf-8"),
            method="POST",
        )
        if create_result["status"] not in (200, 201):
            error_body = create_result["body"]
            if isinstance(error_body, dict):
                error_body = json.dumps(error_body)
            return _json_response(500, {"error": f"Failed to create playlist: {error_body}"})

        playlist_id = create_result["body"]["id"]
        playlist_url = create_result["body"]["external_urls"].get("spotify", "")

        # Add tracks to the playlist (max 100 per request)
        for i in range(0, len(track_uris), 100):
            batch = track_uris[i:i + 100]
            add_result = _http_request(
                f"https://api.spotify.com/v1/playlists/{playlist_id}/tracks",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                },
                data=json.dumps({"uris": batch}).encode("utf-8"),
                method="POST",
            )
            if add_result["status"] not in (200, 201):
                pass  # Continue even if a batch fails

        return _json_response(201, {
            "message": "Playlist created successfully",
            "playlist_id": playlist_id,
            "playlist_url": playlist_url,
        })
    except Exception as e:
        return _json_response(500, {"error": str(e)})


def handle_get_playlist_preferences(event):
    """GET /api/me/playlists/preferences — return current preferences and available genres."""
    user_id, err = _require_auth(event)
    if err:
        return err

    try:
        prefs = _get_user_playlist_preferences(user_id)

        token = _get_user_access_token(user_id)
        available_genres = []
        if token:
            available_genres = _fetch_available_genre_seeds(token)

        return _json_response(200, {
            "preferences": prefs,
            "available_genres": available_genres,
        })
    except Exception as e:
        return _json_response(500, {"error": str(e)})


def handle_put_playlist_preferences(event):
    """PUT /api/me/playlists/preferences — validate and save playlist preferences."""
    user_id, err = _require_auth(event)
    if err:
        return err

    try:
        body = json.loads(event.get("body") or "{}")
    except (json.JSONDecodeError, TypeError):
        return _json_response(400, {"error": "Invalid JSON body"})

    try:
        current = _get_user_playlist_preferences(user_id)
        validated = dict(current)

        if "timeframe" in body:
            validated["timeframe"] = body["timeframe"]
        if "exclude_listened" in body:
            validated["exclude_listened"] = bool(body["exclude_listened"])
        if "genres" in body:
            validated["genres"] = list(body["genres"])[:15]
        if "discovery_genres" in body:
            validated["discovery_genres"] = list(body["discovery_genres"])[:15]
        if "excluded_genres" in body:
            validated["excluded_genres"] = list(body["excluded_genres"])[:15]

        _save_user_playlist_preferences(user_id, validated)

        # Invalidate playlist cache since preferences changed
        table = _get_dynamodb().Table(INSIGHTS_TABLE)
        table.delete_item(Key={"user_id": user_id, "insight_key": "playlist_suggestions"})

        return _json_response(200, {"preferences": validated, "message": "Preferences saved"})

    except ValueError as e:
        return _json_response(400, {"error": str(e)})
    except Exception as e:
        return _json_response(500, {"error": str(e)})


def handle_available_genres(event):
    """GET /api/me/playlists/genres — return valid Spotify genre seeds."""
    user_id, err = _require_auth(event)
    if err:
        return err

    try:
        token = _get_user_access_token(user_id)
        if not token:
            return _json_response(401, {"error": "Spotify account not connected"})

        genres = _fetch_available_genre_seeds(token)
        return _json_response(200, {"genres": genres, "count": len(genres)})
    except Exception as e:
        return _json_response(500, {"error": str(e)})


def handle_playlist_regenerate(event):
    """POST /api/me/playlists/regenerate — force-regenerate all playlists (bypass cache)."""
    user_id, err = _require_auth(event)
    if err:
        return err

    try:
        table = _get_dynamodb().Table(INSIGHTS_TABLE)
        table.delete_item(Key={"user_id": user_id, "insight_key": "playlist_suggestions"})

        if "queryStringParameters" not in event or event["queryStringParameters"] is None:
            event["queryStringParameters"] = {}
        event["queryStringParameters"]["force"] = "true"

        return handle_playlist_suggestions(event)
    except Exception as e:
        return _json_response(500, {"error": str(e)})


# ─── Scheduled Handler (EventBridge) ─────────────────────────────────────────
def handle_scheduled_refresh(event):
    """Scheduled job (every 3 days): refresh public new releases and generate playlists for all users."""
    errors = []
    summary = {"new_releases": 0, "users_processed": 0, "users_failed": 0}

    # 1. Refresh public new releases
    try:
        client_id, client_secret = _get_spotify_app_credentials()
        client_token = _get_client_token(client_id, client_secret)
        releases = _fetch_new_releases(client_token)

        s3 = _get_s3()
        s3.put_object(
            Bucket=S3_BUCKET,
            Key="data/spotify_data.json",
            Body=json.dumps({"albums": releases}),
            ContentType="application/json",
        )
        summary["new_releases"] = len(releases)
    except Exception as e:
        errors.append(f"New releases refresh failed: {e}")

    # 2. Generate playlists for all users with tokens
    try:
        tokens_table = _get_dynamodb().Table(TOKENS_TABLE)
        scan_kwargs = {}
        user_ids = []

        while True:
            resp = tokens_table.scan(**scan_kwargs)
            for item in resp.get("Items", []):
                uid = item.get("user_id")
                if uid:
                    user_ids.append(uid)
            last_key = resp.get("LastEvaluatedKey")
            if not last_key:
                break
            scan_kwargs["ExclusiveStartKey"] = last_key

        for uid in user_ids:
            try:
                token = _get_user_access_token(uid)
                if not token:
                    continue

                # Record recent plays
                _record_recent_plays(uid, token)

                # Get preferences and generate playlists
                prefs = _get_user_playlist_preferences(uid)
                timeframe = prefs["timeframe"]

                h_plays = _build_play_history(uid, timeframe)
                h_stats = _compute_taste_stats(h_plays)
                supplement_data = _build_spotify_supplement(token, timeframe)

                exclusion_set = set()
                if prefs.get("exclude_listened", True):
                    exclusion_set = _build_exclusion_set(h_plays, supplement_data["tracks"])

                available_genres = _fetch_available_genre_seeds(token)
                available_genres_set = set(available_genres)

                valid_user_genres = [g for g in prefs.get("genres", []) if g in available_genres_set]
                valid_discovery_genres = [g for g in prefs.get("discovery_genres", []) if g in available_genres_set]
                excluded_genres_set = set(prefs.get("excluded_genres", []))

                merged_plays = None
                merged_stats = None

                def _get_merged_inner():
                    nonlocal merged_plays, merged_stats
                    if merged_plays is None:
                        merged_plays = _merge_plays_with_supplement(h_plays, supplement_data)
                        merged_stats = _compute_taste_stats(merged_plays)
                    return merged_stats

                playlists = []
                for theme in PLAYLIST_THEMES:
                    pid = theme["id"]
                    params = dict(theme["default_params"])
                    seeds_a, seeds_t, seeds_g = [], [], []

                    if pid == "essentials":
                        genre_count = len(valid_user_genres)
                        stats = _get_merged_inner() if _should_supplement(h_stats, pid, genre_count) else h_stats
                        if excluded_genres_set and stats["top_artist_ids"]:
                            artist_genre_map = supplement_data.get("genres_map", {})
                            filtered_artists = []
                            for aid, _cnt in stats["top_artist_ids"]:
                                agenres = set(artist_genre_map.get(aid, []))
                                if not agenres.intersection(excluded_genres_set):
                                    filtered_artists.append(aid)
                                if len(filtered_artists) >= 3:
                                    break
                            seeds_a = filtered_artists[:3]
                        else:
                            seeds_a = [aid for aid, _ in stats["top_artist_ids"][:3]]
                        seeds_t = [tid for tid, _ in stats["top_track_ids"][:2]]
                        total = len(seeds_a) + len(seeds_t)
                        if total > 5:
                            seeds_t = seeds_t[:max(0, 5 - len(seeds_a))]

                    elif pid in ("hidden_gems", "energy_boost", "chill_mode"):
                        genre_count = len(valid_user_genres)
                        stats = _get_merged_inner() if _should_supplement(h_stats, pid, genre_count) else h_stats
                        if valid_user_genres:
                            seeds_g = valid_user_genres[:5]
                        else:
                            top_g = sorted(stats["genre_counts"].items(), key=lambda x: x[1], reverse=True)
                            seeds_g = [g for g, _ in top_g if g in available_genres_set][:5]
                        if not seeds_g:
                            seeds_a = [aid for aid, _ in stats["top_artist_ids"][:5]]

                    elif pid == "discovery_mix":
                        genre_count = len(valid_discovery_genres)
                        stats = _get_merged_inner() if _should_supplement(h_stats, pid, genre_count) else h_stats
                        user_genre_set = set(stats["genre_counts"].keys())
                        if valid_discovery_genres:
                            seeds_g = valid_discovery_genres[:5]
                        else:
                            seeds_g = [g for g in available_genres if g not in user_genre_set][:5]
                        if not seeds_g:
                            seeds_g = available_genres[:5]

                    if not seeds_a and not seeds_t and not seeds_g:
                        playlists.append({
                            "id": pid, "name": theme["name"],
                            "description": theme["description"], "tracks": [],
                        })
                        continue

                    tracks = _fetch_recommendations(
                        token,
                        seed_artists=seeds_a or None,
                        seed_tracks=seeds_t or None,
                        seed_genres=seeds_g or None,
                        **params,
                    )
                    if prefs.get("exclude_listened", True) and exclusion_set:
                        tracks = _filter_exclusions(tracks, exclusion_set)
                    tracks = tracks[:20]

                    playlists.append({
                        "id": pid, "name": theme["name"],
                        "description": theme["description"], "tracks": tracks,
                    })

                result = {
                    "playlists": playlists,
                    "preferences": prefs,
                    "stats": {
                        "total_plays": h_stats["N"],
                        "unique_tracks": h_stats["U_tracks"],
                        "unique_genres": h_stats["U_genres"],
                        "timeframe": timeframe,
                        "timeframe_label": TIMEFRAME_CONFIG[timeframe]["label"],
                        "supplemented": merged_stats is not None,
                    },
                }

                insights_table = _get_dynamodb().Table(INSIGHTS_TABLE)
                now = int(time.time())
                insights_table.put_item(Item={
                    "user_id": uid,
                    "insight_key": "playlist_suggestions",
                    "data": json.dumps(result),
                    "created_at": now,
                    "expires_at": now + PLAYLIST_CACHE_TTL,
                })
                summary["users_processed"] += 1

            except Exception as ue:
                summary["users_failed"] += 1
                errors.append(f"User {uid}: {ue}")

    except Exception as e:
        errors.append(f"User playlist generation scan failed: {e}")

    status = 200 if not errors else 207
    return {
        "statusCode": status,
        "body": json.dumps({
            "summary": summary,
            "errors": errors[:10] if errors else [],
        }),
    }


# ─── Router ──────────────────────────────────────────────────────────────────
ROUTES = {
    # Auth
    ("GET",    "/api/auth/login"):           handle_login,
    ("GET",    "/api/auth/callback"):        handle_callback,
    ("POST",   "/api/auth/logout"):          handle_logout,
    ("GET",    "/api/auth/logout"):          handle_logout,
    ("GET",    "/api/auth/status"):          handle_auth_status,
    ("POST",   "/api/auth/acknowledge-policy"): handle_acknowledge_policy,
    # Owner public endpoints (no auth needed — uses owner's stored tokens)
    ("GET",    "/api/owner/top-artists"):       handle_owner_top_artists,
    ("GET",    "/api/owner/top-albums"):        handle_owner_top_albums,
    ("GET",    "/api/owner/recent-listens"):    handle_owner_recent_listens,
    ("GET",    "/api/owner/top-genres"):        handle_owner_top_genres,
    ("GET",    "/api/owner/frequent-listens"):  handle_owner_frequent_listens,
    # User-scoped endpoints (auth required)
    ("GET",    "/api/me/new-releases"):      handle_new_releases,
    ("GET",    "/api/me/top-artists"):       handle_top_artists,
    ("GET",    "/api/me/top-albums"):        handle_top_albums,
    ("GET",    "/api/me/recent-listens"):    handle_recent_listens,
    ("GET",    "/api/me/top-genres"):        handle_top_genres,
    ("GET",    "/api/me/frequent-listens"):  handle_frequent_listens,
    ("DELETE", "/api/me/data"):              handle_delete_data,
    # Access requests (public)
    ("POST",   "/api/access/request"):       handle_submit_access_request,
    ("GET",    "/api/access/count"):          handle_access_request_count,
    # Admin (owner only)
    ("GET",    "/api/admin/requests"):        handle_admin_list_requests,
    ("POST",   "/api/admin/approve"):         handle_admin_approve_request,
    ("POST",   "/api/admin/reject"):          handle_admin_reject_request,
    # Country stats (public)
    ("GET",    "/api/stats/countries"):        handle_country_stats,
    # Playlist recommendations (auth required)
    ("GET",    "/api/me/playlists/suggestions"):   handle_playlist_suggestions,
    ("POST",   "/api/me/playlists/save"):           handle_save_playlist,
    ("GET",    "/api/me/playlists/preferences"):    handle_get_playlist_preferences,
    ("PUT",    "/api/me/playlists/preferences"):    handle_put_playlist_preferences,
    ("GET",    "/api/me/playlists/genres"):          handle_available_genres,
    ("POST",   "/api/me/playlists/regenerate"):      handle_playlist_regenerate,
}


def lambda_handler(event, context):
    """Main entry point — routes API Gateway HTTP and EventBridge events."""
    # API Gateway v2 events have requestContext.http
    rc = event.get("requestContext", {})
    if "http" in rc:
        method = rc["http"]["method"]
        path = rc["http"]["path"]
        handler = ROUTES.get((method, path))
        if handler:
            return handler(event)
        return _json_response(404, {"error": "Not found"})

    # Fallback: treat as scheduled/EventBridge invocation
    return handle_scheduled_refresh(event)