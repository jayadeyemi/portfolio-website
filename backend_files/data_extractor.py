import os
import requests
import base64
import json
import boto3

# Replace these with your own or store them in environment variables
CLIENT_ID = os.environ.get("SPOTIFY_CLIENT_ID", "YOUR_CLIENT_ID")
CLIENT_SECRET = os.environ.get("SPOTIFY_CLIENT_SECRET", "YOUR_CLIENT_SECRET")

# Must match the Redirect URI in your Spotify Developer Dashboard
REDIRECT_URI = "http://localhost:8888/callback"

# The scope needed to read a user’s private playlists
SCOPE = "playlist-read-private playlist-read-collaborative"

# Spotify Authorization endpoint
AUTHORIZE_URL = "https://accounts.spotify.com/authorize"
# Spotify Token endpoint
TOKEN_URL = "https://accounts.spotify.com/api/token"

def generate_auth_url():
    """
    Generate the URL that the user must visit to allow
    your app to access their Spotify account.
    """
    params = {
        "client_id": CLIENT_ID,
        "response_type": "code",
        "redirect_uri": REDIRECT_URI,
        "scope": SCOPE
    }
    # Convert these params into a query string
    query = "&".join([f"{key}={requests.utils.quote(value)}" for key, value in params.items()])
    return f"{AUTHORIZE_URL}?{query}"

if __name__ == "__main__":
    auth_url = generate_auth_url()
    print("Visit this URL to authorize the application:\n")
    print(auth_url)
