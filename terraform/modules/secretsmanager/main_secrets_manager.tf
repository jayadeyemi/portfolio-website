resource "aws_secretsmanager_secret_version" "secret_version" {
  secret_id     = var.secrets_id
  secret_string = jsonencode(var.spotify_secrets)
}