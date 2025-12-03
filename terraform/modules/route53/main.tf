# Create the hosted zone for the domain
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name = var.domain_name
  }
}

# A record pointing to S3 website endpoint
resource "aws_route53_record" "website" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.create_www_subdomain ? "www.${var.domain_name}" : var.domain_name
  type    = "A"

  alias {
    name                   = var.s3_website_domain
    zone_id                = var.s3_hosted_zone_id
    evaluate_target_health = true
  }
}

# Optional: Create root domain record if using www subdomain
resource "aws_route53_record" "root" {
  count   = var.create_www_subdomain ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.s3_website_domain
    zone_id                = var.s3_hosted_zone_id
    evaluate_target_health = false
  }
}

# API subdomain record pointing to API Gateway
resource "aws_route53_record" "api" {
  count   = var.create_api_record ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = var.api_subdomain
  type    = "A"

  alias {
    name                   = var.api_gateway_domain
    zone_id                = var.api_gateway_zone_id
    evaluate_target_health = false
  }
}
