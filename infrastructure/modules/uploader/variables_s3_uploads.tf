variable "s3_bucket_id" {
  description = "The ID of the S3 bucket"
  type        = string
}

variable "s3_files_map" {
  description = "Mapping of files to be uploaded to S3"
  type = map(object({
    s3_key            = string
    content_type      = string
    processed_content = string
    classification    = string
  }))
}