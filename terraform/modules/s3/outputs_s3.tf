output "bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.website_bucket.bucket
}

# output "bucket_regional_domain_name" {
#   description = "The regional domain name of the S3 bucket"
#   value       = aws_s3_bucket.website_bucket.bucket_regional_domain_name
# }

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.website_bucket.arn
}