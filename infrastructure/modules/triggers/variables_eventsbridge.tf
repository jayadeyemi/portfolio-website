variable "cloudwatch_event_rule_name" {
  description = "The name of the CloudWatch Event Rule."
  type        = string
}

variable "lambda_function_arn" {
  description = "The ARN of the Lambda function to be triggered."
  type        = string
}

variable "lambda_function_name" {
  description = "The name of the Lambda function to be triggered."
  type        = string
}
