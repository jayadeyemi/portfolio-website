variable "project_name" {
  type        = string
  description = "Project name for resource naming"
}


variable "oac_name" {
  description = "The name of the Origin Access Control (OAC)"
  type        = string
}

variable "website_domain_name" {
  description = "The domain name of the website"
  type        = string
}

variable "route53_hosted_zone_id" {
  description = "The ID of the Route 53 hosted zone"
  type        = string
}

variable "website_alternative_names" {
  description = "A list of alternative domain names for the website"
  type        = list(string)
}


variable "cloudfront_aliases" {
  type        = list(string)
  description = "List of domain aliases for the CloudFront distribution"
}

variable "additional_origins" {
  type = list(object({
    domain_name            = string
    origin_id              = string
    http_port              = optional(number, 80)
    https_port             = optional(number, 443)
    origin_protocol_policy = optional(string, "https-only")
    origin_ssl_protocols   = optional(list(string), ["TLSv1.2"])
  }))
  description = "Additional origins for CloudFront"
  default     = []
}

variable "cloudfront_price_class" {
  type        = string
  description = "Price class for the CloudFront distribution (e.g., PriceClass_100, PriceClass_200, PriceClass_All)"
}

variable "cloudfront_distribution_comment" {
  type        = string
  description = "Comment for the CloudFront distribution"
}

variable "cloudfront_origin_id" {
  type        = string
  description = "The ID of the CloudFront origin"
}

variable "subject_alternative_names" {
  type        = list(string)
  description = "Additional domain names for the certificate"
  default     = []
}

variable "frontend_bucket_name" {
  type        = string
  description = "The name of the S3 bucket for the frontend"
}

variable "acm_certificate_name" {
  type        = string
  description = "Name tag for the ACM certificate"
}