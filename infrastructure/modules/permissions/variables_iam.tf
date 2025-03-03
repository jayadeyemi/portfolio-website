variable "lambda_role_name" {
  description = "Name of the IAM role"
  type        = string
}

variable "lambda_policy_name" {
  description = "Name of the IAM policy"
  type        = string
}
variable "lambda_s3_resource_arn" {
  description = "ARN of the S3 bucket objects to be accessed by the Lambda function"
  type        = string
}

variable "lambda_secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret"
  type        = string
}