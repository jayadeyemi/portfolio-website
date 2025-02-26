variable "project_name" {
  description = "The name of the project"
  type        = string
  
}

variable "bucket_name" {
  description = "The name of the S3 bucket"
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
variable "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution"
  type        = string
}