variable "distribution_id" {
  description = "The CloudFront distribution ID to invalidate"
  type        = string
}

variable "content_hash" {
  description = "A hash of all uploaded file contents — changes trigger a new invalidation"
  type        = string
}
