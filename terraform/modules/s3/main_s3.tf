
# S3 Bucket for the static webpage
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name
  
  tags = {
    Name        = var.bucket_name
    project     = var.project_name
  }
}

# Enable public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "website_private_access" {
    bucket                  = aws_s3_bucket.website.id
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "website_ownership" {
  bucket = aws_s3_bucket.website.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
