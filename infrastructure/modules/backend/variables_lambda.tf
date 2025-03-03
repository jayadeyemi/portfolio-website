variable "frontend_bucket_arn" {
  description = "The ARN of the S3 bucket for the frontend"
  type        = string
}

variable "spotify_secret_arn" {
  description = "The ARN of the Secrets Manager secret"
  type        = string
}

variable "lambda_function_name" {
  description = "The name of the IAM role for Lambda execution"
  type        = string
}

variable "lambda_zip_path" {
  description = "The path to the zipped Python Lambda function code"
  type        = string
}

variable "lambda_runtime" {
  description = "The runtime for the Lambda function"
  type        = string
}

variable "lambda_environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
}

variable "lambda_role_name" {
  description = "The name of the IAM role for Lambda execution"
  type        = string 
}

variable "lambda_policy_name" {
  description = "The name of the IAM policy for Lambda execution"
  type        = string
}

# variable "module_name" {
#   description = "Prefix for resource names in this module"
#   type        = string
# }

# variable "runtime" {
#   description = "Lambda runtime (e.g., nodejs14.x)"
#   type        = string
#   default     = "nodejs14.x"
# }

# variable "login_handler" {
#   description = "Handler for the login Lambda function (e.g., login.handler)"
#   type        = string
# }

# variable "callback_handler" {
#   description = "Handler for the callback Lambda function (e.g., callback.handler)"
#   type        = string
# }

# variable "login_lambda_zip" {
#   description = "Path to the zipped login Lambda function package"
#   type        = string
# }

# variable "callback_lambda_zip" {
#   description = "Path to the zipped callback Lambda function package"
#   type        = string
# }

# variable "spotify_secret_name" {
#   description = "Name for the Spotify credentials secret in Secrets Manager"
#   type        = string
# }

# variable "redirect_uri" {
#   description = "Redirect URI for the Spotify OAuth callback"
#   type        = string
# }