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