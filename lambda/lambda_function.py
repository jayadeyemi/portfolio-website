import json
import os
import requests
import base64
import boto3

def get_spotify_credentials(secret_name="SpotifyCredentials", region_name="us-east-1"):

    session = boto3.session.Session()
    client = session.client(service_name="secretsmanager", region_name=region_name)

    try:
        get_secret_value_response = client.get_secret_value(SecretId=secret_name)
    except Exception as e:
        raise Exception(f"Error retrieving secret {secret_name}: {str(e)}")

    # Check if the secret is a string or binary
    if "SecretString" in get_secret_value_response:
        secret = get_secret_value_response["SecretString"]
    else:
        secret = base64.b64decode(get_secret_value_response["SecretBinary"]).decode('utf-8')

    credentials = json.loads(secret)
    return credentials["SPOTIFY_CLIENT_ID"], credentials["SPOTIFY_CLIENT_SECRET"]

def lambda_handler(event, context):
    # Retrieve region from environment variable (or default)
    region = os.environ.get("AWS_REGION", "us-east-1")
    s3_bucket = os.environ.get("S3_BUCKET_NAME")
    secret_name = os.environ.get("SECRET_NAME")

    try:
        client_id, client_secret = get_spotify_credentials(secret_name=secret_name, region_name=region)
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({"error": f"Failed to retrieve Spotify credentials: {str(e)}"})
        }
    
    # Get an access token from Spotify using the Client Credentials Flow
    auth_url = "https://accounts.spotify.com/api/token"
    auth_str = f"{client_id}:{client_secret}"
    b64_auth_str = base64.b64encode(auth_str.encode()).decode("utf-8")
    auth_headers = {"Authorization": f"Basic {b64_auth_str}"}
    auth_data = {"grant_type": "client_credentials"}

    auth_response = requests.post(auth_url, headers=auth_headers, data=auth_data)
    if auth_response.status_code != 200:
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({
                "error": "Failed to authenticate with Spotify",
                "details": auth_response.text
            })
        }
    
    access_token = auth_response.json()["access_token"]

    # Fetch data from Spotify: Example using the Featured Playlists endpoint
    spotify_url = "https://api.spotify.com/v1/browse/featured-playlists"
    headers = {"Authorization": f"Bearer {access_token}"}
    spotify_response = requests.get(spotify_url, headers=headers)
    if spotify_response.status_code != 200:
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({
                "error": "Failed to fetch Spotify data",
                "details": spotify_response.text
            })
        }
    spotify_data = spotify_response.json()

    # Process the Spotify data: extract playlist names and URLs as an example
    processed_data = {
        "playlists": [
            {
                "name": playlist["name"],
                "url": playlist["external_urls"]["spotify"]
            }
            for playlist in spotify_data.get("playlists", {}).get("items", [])
        ]
    }

    s3 = boto3.client("s3", region_name=region)
    object_key = "data/spotify_data.json"
    s3.put_object(
        Bucket=s3_bucket,
        Key=object_key,
        Body=json.dumps(processed_data),
        ContentType="application/json"
    )

    # Return the processed data as a JSON response with CORS enabled
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(processed_data)
    }