output "rest_api_arn" {
  description = "The ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.data_api.arn
}

output "stage_name" {
  description = "The stage name for the API Gateway"
  value       = aws_api_gateway_stage.api_stage.stage_name
}

output "rest_api_id" {
  description = "The ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.data_api.id 
}