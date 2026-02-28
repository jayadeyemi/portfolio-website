############################################################################################################
# KMS Customer Managed Key for Spotify refresh token encryption
# Cost: $1/month per CMK + $0.03 per 10,000 API calls
# Key rotation enabled for security compliance
############################################################################################################

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "token_encryption" {
  description             = "Encrypts Spotify refresh tokens at rest"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  # Default key policy — allows root account full access.
  # Lambda permissions are granted via the Lambda IAM role policy (not here)
  # to avoid circular dependency between modules.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRootAccount"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-token-encryption"
    Project = var.project_name
  }
}

resource "aws_kms_alias" "token_encryption" {
  name          = "alias/${var.project_name}-token-encryption"
  target_key_id = aws_kms_key.token_encryption.key_id
}

############################################################################################################
# End of File
############################################################################################################
