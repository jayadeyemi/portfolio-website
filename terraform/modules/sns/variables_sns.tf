variable "sns_topic_name" {
  description = "The name of the SNS topic"
  type        = string  
}

variable "lambda_function_name" {
  description = "The name of the Lambda function"
  type        = string
}

variable "sns_subscription_email" {
  description = "The email address to subscribe to the SNS topic"
  type        = string
  
}