# File: ./terraform/modules/acm/outputs_acm.tf
# --------------------------------------------------
output "acm_certificate_arn" {
  value       = module.acm.acm_certificate_arn
}


# File: ./terraform/modules/cloudfront/outputs_cloudfront.tf
# --------------------------------------------------
output "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = module.cloudfront.cloudfront_distribution_domain_name
}

output "cloudfront_origin_access_control_id" {
  description = "The ID of the Origin Access Control (OAC) for CloudFront"
  value       = module.cloudfront.cloudfront_origin_access_control_id
}

output "cloudfront_distribution_hosted_zone_id" {
  description = "The hosted zone ID of the CloudFront distribution"
  value       = module.cloudfront.cloudfront_distribution_hosted_zone_id
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = module.cloudfront.cloudfront_distribution_id
}

output "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution"
  value       = module.cloudfront.cloudfront_distribution_arn
}

# File: ./terraform/modules/iam/outputs_iam.tf
# --------------------------------------------------
output "lambda_role_arn" {
  description = "The ARN of the Lambda execution role"
  value       = module.iam.lambda_role_arn
}

# File: ./terraform/modules/lambda/outputs_lambda.tf
# --------------------------------------------------
output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = module.lambda.lambda_function_arn
}

output "lambda_function_name" {
  description = "The name of the Lambda function"
  value       = module.lambda.lambda_function_name
}

# File: ./terraform/modules/route53/outputs_route53.tf
# --------------------------------------------------
output "route53_record_fqdn" {
  description = "The DNS record created for the domain"
  value       = module.route53.route53_record_fqdn
}

# File: ./terraform/modules/s3/outputs_s3.tf
# --------------------------------------------------
output "bucket_name" {
  description = "The name of the S3 bucket"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = module.s3.s3_bucket_arn
}

output "s3_bucket_id" {
  description = "The ID of the S3 bucket"
  value       = module.s3.s3_bucket_id
}

# File: ./terraform/modules/s3_policy/outputs_s3_policy.tf
# --------------------------------------------------


# File: ./terraform/modules/s3_uploads/outputs_s3_uploads.tf
# --------------------------------------------------
# 3. Output the object key or anything else needed
output "uploaded_keys" {
  description = "The S3 object key for the uploaded JS file"
  value       = module.s3_uploads.uploaded_keys
}

# File: ./terraform/modules/secretsmanager/outputs_secrets_manager.tf
# --------------------------------------------------
output "secrets_manager_secret_arn" {
  description = "The ARN of the Secrets Manager secret"
  value       = module.secretsmanager.secrets_manager_secret_arn
}

