# Provider variables
variable "aws_region" {
  description = "The AWS region"
  type        = string
}

variable "project_name" {
  description = "The project name"
  type        = string
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

variable "lambda_path" {
  description = "The path to the Lambda function code"
  type        = string
  
} 

variable "cloudfront_price_class" {
  description = "The price class for the CloudFront distribution"
  type        = string
  default = "PriceClass_100"
}

variable "home_html" {
  description = "The path to the home HTML file"
  type        = string
}

variable "home_css" {
  description = "The path to the home CSS file"
  type        = string
}

variable "spotify_html" {
  description = "The path to the Spotify HTML file"
  type        = string
}

variable "spotify_css" {
  description = "The path to the Spotify CSS file"
  type        = string
}

variable "spotify_js" {
  description = "The path to the Spotify JavaScript file"
  type        = string
}

variable "spotify_js_template" {
  description = "The path to the Spotify JavaScript template file"
  type        = string
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
################################################################################
# End of File
################################################################################
