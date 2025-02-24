variable "s3_bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "cloudfront_oai_canonical_user_id" {
  description = "The canonical user ID of the CloudFront Origin Access Identity"
  type        = string
}

variable "s3_files" {
  description = "Mapping of files to be uploaded to S3"
  type = map(object({
    s3_key       = string
    source       = string
    content_type = string
  }))
}