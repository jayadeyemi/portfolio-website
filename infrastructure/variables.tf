# Provider variables
variable "aws_region" {
  description = "The AWS region"
  type        = string
}

variable "project_name" {
  description = "The project name"
  type        = string
} 

variable "project_suffix" {
  description = "Unique suffix appended to globally-scoped resource names (e.g. S3 bucket). Change this if the default name is already taken."
  type        = string
  default     = "bja01"
}


variable "website_domain_name" {
  description = "The website domain name"
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

variable "lambda_runtime" {
  description = "The runtime for the Lambda function"
  type        = string
}

variable "lambda_filename" {
  description = "The filename of the Lambda function code"
  type        = string
}

variable "backend_path" {
  description = "The path to the Lambda function code"
  type        = string
  
} 

variable "cloudfront_price_class" {
  description = "The price class for the CloudFront distribution"
  type        = string
  default = "PriceClass_100"
}

variable "frontend_path" {
  description = "The path to the frontend files"
  type        = string
}

variable "website_alternative_names" {
  description = "Alternative names for the website"
  type        = list(string)
  default     = []
}

variable "lambda_template" {
  description = "The name of the Lambda function file"
  type        = string  
}

variable "s3_file_list" {
  description = "List of files to upload to S3"
  type        = list(string)
}

variable "domain_registrant" {
  description = "Contact details for domain registration (admin, registrant, and tech contacts)"
  sensitive   = true
  type = object({
    first_name     = string
    last_name      = string
    email          = string
    phone_number   = string
    address_line_1 = string
    city           = string
    state          = string
    zip_code       = string
    country_code   = string
  })
}

variable "owner_spotify_user_id" {
  description = "Spotify user ID of the site owner (permanent login, no logout)"
  type        = string
  default     = ""
}

variable "policy_version" {
  description = "Privacy policy version string. Change to notify users of updates."
  type        = string
  default     = "2026-02-27"
}

variable "admin_email" {
  description = "Admin email address for access request notifications"
  type        = string
  default     = ""
}

################################################################################
# End of File
################################################################################
