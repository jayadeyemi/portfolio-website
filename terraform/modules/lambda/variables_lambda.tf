variable "lambda_function_name" {
  description = "The name of the IAM role for Lambda execution"
  type        = string
}

variable "lambda_py_zip" {
  description = "The path to the zipped Python Lambda function code"
  type        = string
}

variable "api_gateway_rest_api_arn" {
  description = "ID of the API Gateway"
  type        = string  
}

variable "lambda_role_arn" {
  description = "The ARN of the IAM role for Lambda execution"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  }

variable "s3_bucket_name" {
  description = "S3 bucket name to store Spotify data and website assets"
  type        = string
}

variable "sns_topic_name" {
  description = "SNS topic name for Lambda failure notifications"
  type        = string
}
