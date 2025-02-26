# CloudFront distribution in front of the S3 bucket
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = var.oac_name
  description                       = "Origin Access Control for S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  price_class         = var.cloudfront_price_class
  enabled             = true
  # is_ipv6_enabled     = true
  comment             = var.cloudfront_distribution_comment
  aliases             = var.cloudfront_aliases
  default_root_object = "index.html"

  origin {
    domain_name               = var.s3_bucket_domain_name
    origin_id                 = var.cloudfront_origin_id
    origin_access_control_id  = aws_cloudfront_origin_access_control.oac.id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  dynamic "origin" {
    for_each  = var.additional_origins
    content {
      domain_name          = origin.value.domain_name
      origin_id            = origin.value.origin_id
      custom_origin_config {
        http_port              = lookup(origin.value, "http_port", 80)
        https_port             = lookup(origin.value, "https_port", 443)
        origin_protocol_policy = lookup(origin.value, "origin_protocol_policy", "https-only")
        origin_ssl_protocols   = lookup(origin.value, "origin_ssl_protocols", ["TLSv1.2"])
      }
    }
  }
  # Default cache behavior
  default_cache_behavior {
    allowed_methods           = ["GET", "HEAD", "OPTIONS"]
    cached_methods            = ["GET", "HEAD", "OPTIONS"]
    target_origin_id          = var.cloudfront_origin_id
    viewer_protocol_policy    = "redirect-to-https"
    compress                  = true    
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
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
    acm_certificate_arn = var.acm_certificate_arn
    ssl_support_method  = "sni-only"
  }
  tags = {
    Name = var.cloudfront_distribution_comment
    project = var.project_name
  }
}
