# CloudFront Origin Access Control for S3
resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${var.project_name}-oac"
  description                       = "OAC for ${var.domain_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} website distribution"
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # Use only North America and Europe

  # Aliases (custom domain names)
  aliases = var.create_www_alias ? [
    var.domain_name,
    "www.${var.domain_name}"
  ] : [var.domain_name]

  # Origin configuration pointing to S3 website endpoint
  origin {
    domain_name = var.s3_website_endpoint
    origin_id   = "S3-${var.s3_bucket_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.s3_bucket_name}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  # Custom error response for SPA routing
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  }

  # SSL/TLS certificate configuration
  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name      = "${var.project_name}-distribution"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}
