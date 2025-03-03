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

