variable "website_domain_name" {
  description = "The domain name of the website"
  type        = string
}

variable "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  type        = string
}

variable "cloudfront_hosted_zone_id" {
  description = "The ID of the CloudFront hosted zone"
  type        = string
  
}

variable "route53_hosted_zone_id" {
  description = "The ID of the Route 53 hosted zone"
  type        = string
}