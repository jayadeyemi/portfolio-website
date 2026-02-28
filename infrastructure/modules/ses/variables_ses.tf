variable "website_domain_name" {
  description = "Domain name for SES email identity"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for DNS verification records"
  type        = string
}

variable "aws_region" {
  description = "AWS region for SES Mail FROM MX record"
  type        = string
}

############################################################################################################
# End of File
############################################################################################################
