
# S3 Bucket for the static webpage
resource "aws_s3_bucket" "website_bucket" {
  bucket = var.s3_bucket_name
}

# Enable public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "static_site_private_access" {
    bucket                  = aws_s3_bucket.website_bucket.id
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "static_site_ownership" {
  bucket = aws_s3_bucket.website_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "static_site_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.static_site_ownership,
    aws_s3_bucket_public_access_block.static_site_private_access
  ]

  bucket = aws_s3_bucket.website_bucket.id
  acl    = "public-read"
}

resource "aws_s3_object" "files" {
  for_each     = var.s3_files
  bucket       = aws_s3_bucket.website_bucket.id
  key          = each.value.s3_key
  source       = each.value.source
  content_type = each.value.content_type
}


resource "aws_s3_bucket_policy" "static_site_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowCloudFrontAccess",
        "Effect": "Allow",
        "Principal": {
          "AWS": "${var.origin_access_identity}"
        },
        "Action": "s3:GetObject",
        "Resource": "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })
}

