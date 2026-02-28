output "data_processor_function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.data_processor.arn
}

output "data_processor_function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.data_processor.function_name
}

output "data_processor_invoke_arn" {
  description = "The invoke ARN of the Lambda function (for API Gateway integration)"
  value       = aws_lambda_function.data_processor.invoke_arn
}

output "data_processor_role_arn" {
  description = "The ARN of the Lambda execution role"
  value       = aws_iam_role.data_processor_role.arn
}