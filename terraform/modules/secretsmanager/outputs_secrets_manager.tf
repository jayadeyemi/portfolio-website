output "secrets_manager_secret_arn" {
  description = "The ARN of the Secrets Manager secret"
  value       = aws_secretsmanager_secret_version.secret_version.arn
}