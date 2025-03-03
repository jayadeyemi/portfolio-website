############################################################################################################
# Terraform Provider Configuration
############################################################################################################
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"

      configuration_aliases = [
        aws.us_east_1
      ]
    } 
  }
}

############################################################################################################
# ACM Certificate Resources
############################################################################################################
# ACM Certificate for the static website
resource "aws_acm_certificate" "cert" {
  provider                  = aws.us_east_1
  domain_name               = var.website_domain_name
  validation_method         = "DNS"
  subject_alternative_names = var.subject_alternative_names

  tags = {
    Name    = var.acm_certificate_name
    Project = var.project_name
  }
}

# ACM Certificate Validation
resource "aws_acm_certificate_validation" "cert_validation" {
  provider               = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
  }

# Route53 Record for the ACM Certificate Validation
resource "aws_route53_record" "cert_validation" {
  provider = aws.us_east_1
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = var.route53_hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

############################################################################################################
# Route53 Resources
############################################################################################################
# Route53 Record for the static website
resource "aws_route53_record" "static_site_record" {
  zone_id = var.route53_hosted_zone_id
  name    = var.website_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 Record for the alternative domain names
resource "aws_route53_record" "alternative_aliases" {
  for_each = toset(var.website_alternative_names)
  zone_id  = var.route53_hosted_zone_id
  name     = each.value
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}


############################################################################################################
# CloudFront distribution Resources
############################################################################################################
# Origin Access Control for the S3 bucket
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = var.oac_name
  description                       = "Origin Access Control for S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront distribution for the static website
resource "aws_cloudfront_distribution" "this" {
  price_class         = var.cloudfront_price_class
  enabled             = true
  # is_ipv6_enabled     = true
  comment             = var.cloudfront_distribution_comment
  aliases             = var.cloudfront_aliases
  default_root_object = "index.html"

  origin {
    domain_name               = aws_s3_bucket.website.bucket_domain_name
    origin_id                 = var.cloudfront_origin_id
    origin_access_control_id  = aws_cloudfront_origin_access_control.oac.id
  }

  # Default cache behavior
  default_cache_behavior {
    target_origin_id       = var.cloudfront_origin_id
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    viewer_protocol_policy = "redirect-to-https"
    
    compress    = true    
    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method  = "sni-only"
  }
  tags = {
    Name = var.cloudfront_distribution_comment
    project = var.project_name
  }
}

############################################################################################################
# S3 Bucket Resources
############################################################################################################
# S3 Bucket for the static webpages
resource "aws_s3_bucket" "website" {
  bucket = var.frontend_bucket_name
  
  tags = {
    Name        = var.frontend_bucket_name
    project     = var.project_name
  }
}

# Access Restrictions for the S3 Bucket
resource "aws_s3_bucket_public_access_block" "website_private_access" {
    bucket                  = aws_s3_bucket.website.id
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

# Ownership Controls for the S3 Bucket
resource "aws_s3_bucket_ownership_controls" "website_ownership" {
  bucket = aws_s3_bucket.website.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Bucket Policy for the S3 Bucket
resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website.bucket

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
            "AWS:SourceArn": aws_cloudfront_distribution.this.arn
          }
        }
      }
    ]
  })
}

############################################################################################################
# End of File
############################################################################################################