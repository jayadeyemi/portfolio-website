resource "aws_secretsmanager_secret" "spotify_secret" {
  name = "SpotifyCredentials"

  # This lifecycle block prevents Terraform from destroying the secret
  # if someone runs 'terraform destroy' or removes it from state.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "spotify_secret_version" {
  secret_id     = aws_secretsmanager_secret.spotify_secret.id
  secret_string = jsonencode({
    SPOTIFY_CLIENT_ID     = var.spotify_client_id,
    SPOTIFY_CLIENT_SECRET = var.spotify_client_secret
  })
}