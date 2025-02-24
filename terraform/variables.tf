# Provider variables
variable "aws_region" {
  description = "The AWS region"
  type        = string
}

variable "project_name" {
  description = "The project name"
  type        = string
} 

variable "environment" {
  description = "The environment"
  type        = string
}

variable "website_domain_name" {
  description = "The website domain name"
  type        = string
}

variable "sns_subscription_email" {
  description = "The email address to subscribe to the SNS topic"
  type        = string
}

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