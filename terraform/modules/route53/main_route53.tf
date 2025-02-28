

resource "aws_route53_record" "static_site_record" {
  zone_id = var.route53_hosted_zone_id
  name    = var.website_domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_distribution_domain_name
    zone_id                = var.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alternative_aliases" {
  for_each = toset(var.website_alternative_names)
  zone_id  = var.route53_hosted_zone_id
  name     = each.value
  type     = "A"

  alias {
    name                   = var.cloudfront_distribution_domain_name
    zone_id                = var.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }
}
