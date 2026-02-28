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
# Route 53 Hosted Zone (Terraform-managed)
############################################################################################################
resource "aws_route53_zone" "primary" {
  name = var.website_domain_name

  tags = {
    Name    = var.website_domain_name
    Project = var.project_name
  }
}

############################################################################################################
# Domain Registration (Route53 Domains)
# NOTE: This registers babasanmiadeyemi.com via AWS Route53 Domains (~$12/yr for .com).
# The domain is pointed at the Route53 hosted zone nameservers created above.
# Allow up to 30 minutes for registration to complete on first apply.
############################################################################################################
resource "aws_route53domains_domain" "this" {
  provider    = aws.us_east_1
  domain_name = var.website_domain_name
  auto_renew  = true

  # Point to our Terraform-managed Route53 hosted zone
  dynamic "name_server" {
    for_each = aws_route53_zone.primary.name_servers
    content {
      name = name_server.value
    }
  }

  admin_contact {
    contact_type   = "PERSON"
    first_name     = var.domain_registrant.first_name
    last_name      = var.domain_registrant.last_name
    email          = var.domain_registrant.email
    phone_number   = var.domain_registrant.phone_number
    address_line_1 = var.domain_registrant.address_line_1
    city           = var.domain_registrant.city
    state          = var.domain_registrant.state
    zip_code       = var.domain_registrant.zip_code
    country_code   = var.domain_registrant.country_code
  }

  registrant_contact {
    contact_type   = "PERSON"
    first_name     = var.domain_registrant.first_name
    last_name      = var.domain_registrant.last_name
    email          = var.domain_registrant.email
    phone_number   = var.domain_registrant.phone_number
    address_line_1 = var.domain_registrant.address_line_1
    city           = var.domain_registrant.city
    state          = var.domain_registrant.state
    zip_code       = var.domain_registrant.zip_code
    country_code   = var.domain_registrant.country_code
  }

  tech_contact {
    contact_type   = "PERSON"
    first_name     = var.domain_registrant.first_name
    last_name      = var.domain_registrant.last_name
    email          = var.domain_registrant.email
    phone_number   = var.domain_registrant.phone_number
    address_line_1 = var.domain_registrant.address_line_1
    city           = var.domain_registrant.city
    state          = var.domain_registrant.state
    zip_code       = var.domain_registrant.zip_code
    country_code   = var.domain_registrant.country_code
  }

  admin_privacy      = true
  registrant_privacy = true
  tech_privacy       = true
  transfer_lock      = true

  tags = {
    Name    = var.website_domain_name
    Project = var.project_name
  }

  lifecycle {
    prevent_destroy = true
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
# depends_on domain registration so NS delegation is live before ACM polls for the CNAME
resource "aws_acm_certificate_validation" "cert_validation" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  depends_on = [aws_route53domains_domain.this]
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

  zone_id = aws_route53_zone.primary.zone_id
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
  zone_id = aws_route53_zone.primary.zone_id
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
  zone_id  = aws_route53_zone.primary.zone_id
  name     = each.value
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

# IPv6 AAAA record for apex domain
resource "aws_route53_record" "static_site_record_ipv6" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.website_domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

# IPv6 AAAA records for alternative domain names
resource "aws_route53_record" "alternative_aliases_ipv6" {
  for_each = toset(var.website_alternative_names)
  zone_id  = aws_route53_zone.primary.zone_id
  name     = each.value
  type     = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}


############################################################################################################
# CloudFront Response Headers Policy — security headers (HSTS, CSP, etc.)
############################################################################################################
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "${var.project_name}-security-headers"
  comment = "Security headers for portfolio site"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }

    content_security_policy {
      content_security_policy = "default-src 'self'; img-src 'self' https://i.scdn.co https://*.scdn.co data:; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'self'; font-src 'self'; object-src 'none'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
      override                = true
    }
  }
}

############################################################################################################
# CloudFront Function — rewrite subdirectory URIs to index.html
############################################################################################################
resource "aws_cloudfront_function" "rewrite_uri" {
  name    = "${var.project_name}-rewrite-uri"
  runtime = "cloudfront-js-2.0"
  comment = "Rewrite directory URIs to index.html for SPA/static site routing"
  publish = true

  code = <<-EOF
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      if (uri.endsWith('/')) {
        request.uri += 'index.html';
      } else if (!uri.includes('.')) {
        request.uri += '/index.html';
      }
      return request;
    }
  EOF
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
  is_ipv6_enabled     = true
  comment             = var.cloudfront_distribution_comment
  aliases             = var.cloudfront_aliases
  default_root_object = "index.html"

  origin {
    domain_name               = aws_s3_bucket.website.bucket_domain_name
    origin_id                 = var.cloudfront_origin_id
    origin_access_control_id  = aws_cloudfront_origin_access_control.oac.id
  }

  # API Gateway origin (added dynamically when api_origin_domain is set)
  dynamic "origin" {
    for_each = var.api_origin_domain != "" ? [1] : []
    content {
      domain_name = var.api_origin_domain
      origin_id   = "${var.project_name}-api-origin"

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # API cache behavior — no caching, forward all cookies/headers
  dynamic "ordered_cache_behavior" {
    for_each = var.api_origin_domain != "" ? [1] : []
    content {
      path_pattern             = "/api/*"
      target_origin_id         = "${var.project_name}-api-origin"
      allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods           = ["GET", "HEAD"]
      viewer_protocol_policy   = "redirect-to-https"
      compress                 = true

      # Managed policies: CachingDisabled + AllViewerExceptHostHeader
      cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
      origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
    }
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

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.rewrite_uri.arn
    }

    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.cert_validation.certificate_arn
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