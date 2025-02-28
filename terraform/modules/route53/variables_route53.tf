variable "website_domain_name" {
  description = "The domain name of the website"
  type        = string
}

variable "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution"
  type        = string
}

variable "cloudfront_distribution_hosted_zone_id" {
  description = "The ID of the CloudFront hosted zone"
  type        = string
}

variable "route53_hosted_zone_id" {
  description = "The ID of the Route 53 hosted zone"
  type        = string
}

variable "acm_certificate_arn" {
  type        = string
  description = "The ARN of the ACM certificate"
}

variable "website_alternative_names" {
  description = "A list of alternative domain names for the website"
  type        = list(string)
}