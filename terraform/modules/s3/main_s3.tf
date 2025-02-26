
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

resource "aws_s3_object" "files" {
  for_each     = var.s3_files
  bucket       = aws_s3_bucket.website.id
  key          = each.value.s3_key
  content_type = each.value.content_type

  source = substr(trimspace(each.value.source), 0, 9) != "<!DOCTYPE" ? each.value.source : null
  content = substr(trimspace(each.value.source), 0, 9) == "<!DOCTYPE" ? each.value.source : null
}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowCloudFrontServicePrincipal",
        "Effect": "Allow",
        "Principal": {
          "Service": "cloudfront.amazonaws.com"
        },
        "Action": "s3:GetObject",
        "Resource": "${aws_s3_bucket.website.arn}/*",
        "Condition": {
          "StringEquals": {
            "AWS:SourceArn": var.cloudfront_distribution_arn
          }
        }
      }
    ]
  })
}
