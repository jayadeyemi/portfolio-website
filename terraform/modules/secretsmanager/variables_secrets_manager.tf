variable "secrets_manager_secret_name" {
  description = "The name of the secret in Secrets Manager"
  type        = string
}

variable "spotify_client_id" {
  description = "Spotify client ID"
  type        = string
  sensitive   = true
}

variable "spotify_client_secret" {
  description = "Spotify client secret"
  type        = string
  sensitive   = true
}