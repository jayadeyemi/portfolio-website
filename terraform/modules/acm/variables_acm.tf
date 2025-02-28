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


variable "acm_certificate_name" {
  type        = string
  description = "Name tag for the ACM certificate"
}

variable "route53_hosted_zone_id" {
  type        = string
  description = "The ID of the Route 53 hosted zone for DNS validation"
}