variable "spotify_secrets" {
  description = "A map containing the Spotify credentials"
  type        = map(string)
}

variable "secrets_id" {
  description = "The ID of the Secrets Manager secret"
  type        = string
}