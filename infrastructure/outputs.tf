# File: ./infrastructure/modules/backend/outputs_lambda.tf
# --------------------------------------------------
output "data_processor_function_arn" {
  description = "The ARN of the Lambda function"
  value       = module.backend.data_processor_function_arn
}

output "data_processor_function_name" {
  description = "The name of the Lambda function"
  value       = module.backend.data_processor_function_name
}

output "data_processor_role_arn" {
  description = "The ARN of the Lambda execution role"
  value       = module.backend.data_processor_role_arn
}

# File: ./infrastructure/modules/frontend/outputs_frontend.tf
# --------------------------------------------------
##############################################################################################################
# Purpose: Outputs for the ACM Section.
##############################################################################################################
output "acm_certificate_arn" {
  value       = module.frontend.acm_certificate_arn
}

output "acm_certificate_domain_validation_options" {
  value       = module.frontend.acm_certificate_domain_validation_options
}

##############################################################################################################
# Purpose: Outputs for the Route53 Section.
##############################################################################################################
output "route53_hosted_zone_id" {
  description = "The ID of the Terraform-managed Route 53 hosted zone"
  value       = module.frontend.route53_hosted_zone_id
}

output "route53_hosted_zone_nameservers" {
  description = "Nameservers to configure at your domain registrar"
  value       = module.frontend.route53_hosted_zone_nameservers
}

output "route53_record_fqdn" {
  description = "The DNS record created for the domain"
  value       = module.frontend.route53_record_fqdn
}

##############################################################################################################
# Purpose: Outputs for the CloudFront Section.
##############################################################################################################
output "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = module.frontend.cloudfront_distribution_domain_name
}

output "cloudfront_origin_access_control_id" {
  description = "The ID of the Origin Access Control (OAC) for CloudFront"
  value       = module.frontend.cloudfront_origin_access_control_id
}

output "cloudfront_distribution_hosted_zone_id" {
  description = "The hosted zone ID of the CloudFront distribution"
  value       = module.frontend.cloudfront_distribution_hosted_zone_id
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = module.frontend.cloudfront_distribution_id
}

output "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution"
  value       = module.frontend.cloudfront_distribution_arn
}

##############################################################################################################
# Purpose: Outputs for the S3 Section.
##############################################################################################################
output "frontend_bucket_name" {
  description = "The name of the S3 bucket"
  value       = module.frontend.frontend_bucket_name
}

output "frontend_bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = module.frontend.frontend_bucket_arn
}

output "frontend_bucket_id" {
  description = "The ID of the S3 bucket"
  value       = module.frontend.frontend_bucket_id
}

output "s3_bucket_domain_name" {
  description = "The domain name of the S3 bucket"
  value       = module.frontend.s3_bucket_domain_name
  
}

##############################################################################################################
# End of file
##############################################################################################################

# File: ./infrastructure/modules/secrets/outputs_secrets_manager.tf
# --------------------------------------------------
output "spotify_secret_arn" {
  description = "The ARN of the Secrets Manager secret"
  value       = module.secrets.spotify_secret_arn
}

# File: ./infrastructure/modules/uploader/outputs_s3_uploads.tf
# --------------------------------------------------
# 3. Output the object key or anything else needed
output "uploaded_keys" {
  description = "The S3 object keys passed to the module"
  value       = module.uploader.uploaded_keys
}

# File: ./infrastructure/modules/dynamodb/outputs_dynamodb.tf
# --------------------------------------------------
output "users_table_name" {
  description = "Name of the DynamoDB users table"
  value       = module.dynamodb.users_table_name
}

output "sessions_table_name" {
  description = "Name of the DynamoDB sessions table"
  value       = module.dynamodb.sessions_table_name
}

output "spotify_tokens_table_name" {
  description = "Name of the DynamoDB spotify_tokens table"
  value       = module.dynamodb.spotify_tokens_table_name
}

output "insights_table_name" {
  description = "Name of the DynamoDB insights table"
  value       = module.dynamodb.insights_table_name
}

# File: ./infrastructure/modules/kms/outputs_kms.tf
# --------------------------------------------------
output "kms_key_arn" {
  description = "ARN of the KMS key for token encryption"
  value       = module.kms.kms_key_arn
}

# File: ./infrastructure/modules/api_gateway/outputs_api_gateway.tf
# --------------------------------------------------
output "api_endpoint" {
  description = "The API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

output "api_domain_name" {
  description = "The API Gateway domain name (for CloudFront)"
  value       = module.api_gateway.api_domain_name
}

output "spotify_redirect_uri" {
  description = "The Spotify OAuth redirect URI — register this in Spotify Developer Dashboard"
  value       = local.spotify_redirect_uri
}

##############################################################################################################
# End of file
##############################################################################################################