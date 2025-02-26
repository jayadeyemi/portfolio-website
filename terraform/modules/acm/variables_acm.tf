variable "project_name" {
  type        = string
  description = "Project name for resource naming"
}

variable "domain_name" {
  type        = string
  description = "Primary domain name for the certificate"
}

variable "subject_alternative_names" {
  type        = list(string)
  description = "Additional domain names for the certificate"
  default     = []
}

variable "route53_zone_id" {
  type        = string
  description = "Route53 hosted zone ID for DNS validation"
}

variable "acm_certificate_name" {
  type        = string
  description = "Name tag for the ACM certificate"
}
