output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.static_site_distribution.domain_name
}

output "cloudfront_oai_canonical_user_id" {
  description = "The canonical user ID of the CloudFront Origin Access Identity"
  value       = aws_cloudfront_origin_access_identity.oai.s3_canonical_user_id
}

output "cloudfront_hosted_zone_id" {
  description = "The hosted zone ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.static_site_distribution.hosted_zone_id
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.static_site_distribution.id
}