data "aws_route53_zone" "selected" {
  name         = "${var.website_domain_name}."
  private_zone = false
}
