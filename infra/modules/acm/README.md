# ACM Module

This module creates and validates SSL/TLS certificates using AWS Certificate Manager (ACM) for secure HTTPS connections. It supports both regional certificates (for API Gateway) and CloudFront certificates (which must be in us-east-1).

## Overview

The ACM module handles the complete certificate lifecycle: requesting a certificate, creating DNS validation records in Route53, and waiting for validation to complete. It uses DNS validation (not email) for automatic, hands-free certificate issuance.

## Features

- SSL/TLS certificate creation with DNS validation
- Support for Subject Alternative Names (SANs) for multiple domains
- Regional certificates for API Gateway
- CloudFront certificates (us-east-1) with provider alias support
- Automatic DNS validation via Route53
- Certificate validation waiter

## Usage

### For API Gateway (Regional Certificate)

```hcl
module "acm_api" {
  source = "./modules/acm"

  domain_name    = "api.example.com"
  hosted_zone_id = "Z1234567890ABC"
}
```

### For CloudFront (us-east-1 Certificate)

```hcl
module "acm_cloudfront" {
  source = "./modules/acm"

  domain_name               = "example.com"
  subject_alternative_names = ["www.example.com"]
  hosted_zone_id            = "Z1234567890ABC"
  use_cloudfront_provider   = true

  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}
```

**Important:** When using `use_cloudfront_provider = true`, you must configure the us-east-1 provider alias:

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
```

## Resources Created

### 1. `aws_acm_certificate` - SSL/TLS Certificate

Requests an SSL certificate from AWS Certificate Manager.

**Why?**
- Enables HTTPS for custom domains (API Gateway, CloudFront)
- Free certificates managed by AWS (auto-renewal)
- `validation_method = "DNS"`: Automatic validation via Route53 (no email required)
- `domain_name`: The primary domain to secure (e.g., `api-contact.example.com`)
- `subject_alternative_names`: Additional domains to include in the certificate

**Lifecycle:**
```terraform
lifecycle {
  create_before_destroy = true
}
```
**Why?** When updating certificates, creates new one before destroying old one to avoid downtime.

### 2. `aws_route53_record.cert_validation` - DNS Validation Records

Creates DNS records in Route53 to prove domain ownership.

**Why?**
- ACM requires proof you own the domain
- DNS validation is automatic and doesn't expire
- Uses `for_each` to handle multiple validation records (for multiple domains)

**How it works:**
```terraform
for_each = {
  for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
    name   = dvo.resource_record_name
    record = dvo.resource_record_value
    type   = dvo.resource_record_type
  }
}
```

ACM provides validation options (one per domain). This loop creates Route53 records for each validation requirement.

**Parameters:**
- `allow_overwrite = true`: Replaces existing validation records if present (useful for revalidation)
- `ttl = 60`: Short TTL (60 seconds) for faster validation
- `name`, `type`, `records`: Come from ACM's validation requirements

### 3. `aws_acm_certificate_validation` - Validation Waiter

Waits for the certificate to be validated and issued.

**Why?**
- Terraform blocks here until validation completes
- Prevents using an unvalidated certificate in API Gateway or CloudFront
- Ensures certificate is ready before dependent resources are created

**How it works:**
```terraform
validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
```
Collects all validation record FQDNs and waits for ACM to verify them.

## Key Design Decisions

### DNS Validation (Not Email)
**Decision:** Uses `validation_method = "DNS"`

**Reasons:**
- Fully automated (no clicking email links)
- Doesn't expire (email validation needs re-verification)
- Works with Terraform automation
- No dependency on email configuration
- More reliable for CI/CD pipelines

### For_Each for Validation Records
**Decision:** Uses `for_each` instead of hardcoded records

**Reasons:**
- Supports multi-domain certificates (e.g., `example.com` + `*.example.com`)
- Handles edge cases where ACM requires multiple validation records
- More robust and future-proof
- Follows Terraform best practices

### Validation Waiter Resource
**Decision:** Includes explicit `aws_acm_certificate_validation` resource

**Reasons:**
- Ensures certificate is fully validated before proceeding
- Prevents "certificate pending validation" errors in API Gateway
- Makes dependencies explicit in Terraform graph
- Better error messages if validation fails

### Create Before Destroy
**Decision:** Lifecycle policy for zero-downtime updates

**Reasons:**
- Certificate updates don't cause outages
- Old certificate stays active until new one is validated
- Critical for production systems
- Prevents brief periods without valid certificate

## Validation Process Flow

```
1. terraform apply
    ↓
2. aws_acm_certificate created (status: PENDING_VALIDATION)
    ↓
3. ACM generates validation requirements
    ↓
4. aws_route53_record creates CNAME validation record
    ↓
5. Route53 publishes DNS record
    ↓
6. ACM continuously checks DNS for validation record
    ↓
7. Validation found → Certificate issued (status: ISSUED)
    ↓
8. aws_acm_certificate_validation completes
    ↓
9. Terraform proceeds with dependent resources (API Gateway)
```

**Timeline:** Usually 5-10 minutes, but can take up to 30 minutes.

## Usage

### For API Gateway
```terraform
module "acm_api" {
  source = "./modules/acm"

  domain_name    = "api-contact.example.com"
  environment    = "prod"
  hosted_zone_id = module.route53.hosted_zone_id
}

# Use in API Gateway
resource "aws_api_gateway_domain_name" "api" {
  domain_name              = "api-contact.example.com"
  regional_certificate_arn = module.acm_api.certificate_arn  # ← Here
}
```

### For CloudFront (Website)
```terraform
module "acm_website" {
  source = "./modules/acm"
  
  # IMPORTANT: CloudFront certificates MUST be in us-east-1
  providers = {
    aws = aws.us-east-1
  }

  domain_name    = "example.com"
  environment    = "prod"
  hosted_zone_id = module.route53.hosted_zone_id
}
```

## Important Notes

### Region Requirements

**API Gateway (Regional):**
- Certificate must be in the SAME region as API Gateway
- Example: API in `mx-central-1` → Certificate in `mx-central-1`

**CloudFront:**
- Certificate MUST be in `us-east-1` (CloudFront requirement)
- Regardless of where your S3 bucket is

### Validation Time
- Typical: 5-10 minutes
- Maximum: Up to 30 minutes
- `terraform apply` will wait during this time
- If it takes longer, check:
  - Route53 hosted zone is correct
  - DNS has propagated
  - No conflicting DNS records

### Certificate Renewal
- ACM auto-renews certificates before expiration
- Renewal uses the same DNS validation records
- No Terraform changes needed for renewal
- Check certificate status in AWS Console if renewal fails

## Troubleshooting

### Validation Timeout
**Error:** Certificate validation times out

**Solutions:**
1. Verify `hosted_zone_id` is correct
2. Check Route53 hosted zone contains the domain
3. Ensure domain name servers point to Route53
4. Wait longer (can take 30+ minutes in rare cases)

### Wrong Region
**Error:** Certificate not found when used in API Gateway

**Solution:** Ensure certificate is in the same region as API Gateway (or `us-east-1` for CloudFront)

### Multiple Domains
To secure multiple domains with one certificate:
```terraform
resource "aws_acm_certificate" "api" {
  domain_name               = "example.com"
  subject_alternative_names = ["*.example.com", "www.example.com"]
  validation_method         = "DNS"
}
```

## Outputs

- `certificate_arn` - For API Gateway/CloudFront configuration
- `certificate_domain` - The domain name protected by certificate

## Security Considerations

- ✅ Free SSL certificates from AWS
- ✅ Automatic renewal (no expiration issues)
- ✅ DNS validation is more secure than email validation
- ✅ Certificates are validated and trusted by all major browsers
- ✅ Supports modern TLS protocols only (no SSLv3, TLS 1.0)