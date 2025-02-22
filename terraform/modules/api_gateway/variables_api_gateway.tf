variable "api_gateway_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function to integrate with API Gateway"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}