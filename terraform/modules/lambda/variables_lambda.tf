variable "lambda_function_name" {
  description = "The name of the IAM role for Lambda execution"
  type        = string
}

variable "lambda_zip_path" {
  description = "The path to the zipped Python Lambda function code"
  type        = string
}

variable "lambda_role_arn" {
  description = "The ARN of the IAM role for Lambda execution"
  type        = string
}

variable "lambda_runtime" {
  description = "The runtime for the Lambda function"
  type        = string
}

variable "lambda_filename" {
  description = "The filename of the Lambda function code"
  type        = string
}

variable "lambda_environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
}

