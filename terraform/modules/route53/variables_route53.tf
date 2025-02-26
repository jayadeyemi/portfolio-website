variable "website_domain_zone_id" {
  description = "The ID of the Route 53 hosted zone for the website domain"
  type        = string
}

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