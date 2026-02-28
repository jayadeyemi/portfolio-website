output "users_table_name" {
  description = "Name of the users DynamoDB table"
  value       = aws_dynamodb_table.users.name
}

output "users_table_arn" {
  description = "ARN of the users DynamoDB table"
  value       = aws_dynamodb_table.users.arn
}

output "spotify_tokens_table_name" {
  description = "Name of the spotify_tokens DynamoDB table"
  value       = aws_dynamodb_table.spotify_tokens.name
}

output "spotify_tokens_table_arn" {
  description = "ARN of the spotify_tokens DynamoDB table"
  value       = aws_dynamodb_table.spotify_tokens.arn
}

output "sessions_table_name" {
  description = "Name of the sessions DynamoDB table"
  value       = aws_dynamodb_table.sessions.name
}

output "sessions_table_arn" {
  description = "ARN of the sessions DynamoDB table"
  value       = aws_dynamodb_table.sessions.arn
}

output "insights_table_name" {
  description = "Name of the insights DynamoDB table"
  value       = aws_dynamodb_table.insights.name
}

output "insights_table_arn" {
  description = "ARN of the insights DynamoDB table"
  value       = aws_dynamodb_table.insights.arn
}

output "access_requests_table_name" {
  description = "Name of the access_requests DynamoDB table"
  value       = aws_dynamodb_table.access_requests.name
}

output "access_requests_table_arn" {
  description = "ARN of the access_requests DynamoDB table"
  value       = aws_dynamodb_table.access_requests.arn
}

output "play_history_table_name" {
  description = "Name of the play_history DynamoDB table"
  value       = aws_dynamodb_table.play_history.name
}

output "play_history_table_arn" {
  description = "ARN of the play_history DynamoDB table"
  value       = aws_dynamodb_table.play_history.arn
}

############################################################################################################
# End of File
############################################################################################################
