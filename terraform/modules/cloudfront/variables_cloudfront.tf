variable "project_name" {
  type        = string
  description = "Project name for resource naming"
}


variable "oac_name" {
  description = "The name of the Origin Access Control (OAC)"
  type        = string
}

variable "cloudfront_origin_id" {
  description = "The ID of the origin (S3 bucket)"
  type        = string
}

variable "s3_bucket_domain_name" {
  type        = string
  description = "S3 bucket domain name for CloudFront origin (e.g., bucket-name.s3.amazonaws.com)"
}

variable "cloudfront_aliases" {
  type        = list(string)
  description = "List of domain aliases for the CloudFront distribution"
}

variable "acm_certificate_arn" {
  type        = string
  description = "ARN of the ACM certificate covering the domain"
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