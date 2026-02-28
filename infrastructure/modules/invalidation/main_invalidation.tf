##############################################################################################################
# CloudFront Cache Invalidation
# Automatically creates a wildcard invalidation whenever uploaded files change.
# Triggered by a locally-computed content hash (stable between plan and apply).
##############################################################################################################

resource "terraform_data" "cloudfront_invalidation" {
  triggers_replace = var.content_hash

  provisioner "local-exec" {
    command = "aws cloudfront create-invalidation --distribution-id ${var.distribution_id} --paths \"/*\""
  }
}
