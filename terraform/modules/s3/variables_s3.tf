variable "s3_bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "origin_access_identity" {
  description = "The origin access identity for CloudFront"
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