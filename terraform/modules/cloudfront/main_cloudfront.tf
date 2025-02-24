# CloudFront distribution in front of the S3 bucket
resource "aws_cloudfront_distribution" "static_site_distribution" {
  origin {
    domain_name = var.cloudfront_origin_domain_name
    origin_id   = var.cloudfront_origin_id
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "static/index.html"
 
  # Default cache behavior
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = var.cloudfront_origin_id
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  # Ordered behavior for dynamic visualization data
  ordered_cache_behavior {
    path_pattern     = "/data/spotify_data.json"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = var.cloudfront_origin_id
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 80000
    default_ttl            = 86400
    max_ttl                = 100000
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Origin Access Identity for CloudFront to access the S3 bucket
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for static site distribution"
}
