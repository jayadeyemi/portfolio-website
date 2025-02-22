output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.static_site_distribution.domain_name
}

output "cloudfront_oai_iam_arn" {
  description = "The IAM ARN of the CloudFront Origin Access Identity"
  value       = aws_cloudfront_origin_access_identity.oai.iam_arn
}

output "cloudfront_hosted_zone_id" {
  description = "The hosted zone ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.static_site_distribution.hosted_zone_id
}