output "kms_key_arn" {
  description = "ARN of the KMS key for token encryption"
  value       = aws_kms_key.token_encryption.arn
}

output "kms_key_id" {
  description = "ID of the KMS key for token encryption"
  value       = aws_kms_key.token_encryption.key_id
}

output "kms_alias_arn" {
  description = "ARN of the KMS key alias"
  value       = aws_kms_alias.token_encryption.arn
}

############################################################################################################
# End of File
############################################################################################################
