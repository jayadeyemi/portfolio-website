# Route 53 DNS record to point your domain to CloudFront
resource "aws_route53_record" "static_site_record" {
  zone_id = "YOUR_ROUTE53_ZONE_ID"  # Replace with your Route 53 hosted zone ID
  name    = var.website_domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}