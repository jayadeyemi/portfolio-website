
resource "aws_secretsmanager_secret" "this" {
  name                    = var.secret_name
  recovery_window_in_days = 0

  tags = {
    Name    = var.secret_name
    Project = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "secret_version" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = jsonencode(var.spotify_secrets)
}