variable "secret_name" {
  description = "The name of the Secrets Manager secret to create"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "spotify_secrets" {
  description = "A map containing the Spotify credentials"
  type        = map(string)
}