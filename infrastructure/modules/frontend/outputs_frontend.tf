##############################################################################################################
# Purpose: Outputs for the ACM Section.
##############################################################################################################
output "acm_certificate_arn" {
  value = aws_acm_certificate.cert.arn
}

output "acm_certificate_domain_validation_options" {
  value = aws_acm_certificate.cert.domain_validation_options
}

##############################################################################################################
# Purpose: Outputs for the Route53 Section.
##############################################################################################################
output "route53_record_fqdn" {
  description = "The DNS record created for the domain"
  value       = aws_route53_record.static_site_record.fqdn
}

##############################################################################################################
# Purpose: Outputs for the CloudFront Section.
##############################################################################################################
output "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_origin_access_control_id" {
  description = "The ID of the Origin Access Control (OAC) for CloudFront"
  value       = aws_cloudfront_origin_access_control.oac.id
}

output "cloudfront_distribution_hosted_zone_id" {
  description = "The hosted zone ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.id
}

output "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.arn
}

##############################################################################################################
# Purpose: Outputs for the S3 Section.
##############################################################################################################
output "frontend_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.website.bucket
}

output "frontend_bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.website.arn
}

output "frontend_bucket_id" {
  description = "The ID of the S3 bucket"
  value       = aws_s3_bucket.website.id
}

output "s3_bucket_domain_name" {
  description = "The domain name of the S3 bucket"
  value       = aws_s3_bucket.website.bucket_domain_name
  
}

##############################################################################################################
# End of file
##############################################################################################################