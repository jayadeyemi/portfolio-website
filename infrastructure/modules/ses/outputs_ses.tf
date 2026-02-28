output "ses_domain_identity_arn" {
  description = "ARN of the SES domain identity"
  value       = aws_ses_domain_identity.domain.arn
}

output "ses_domain_name" {
  description = "Verified SES domain name"
  value       = aws_ses_domain_identity.domain.domain
}

############################################################################################################
# End of File
############################################################################################################
