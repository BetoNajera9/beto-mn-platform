# CloudFront Module

This module creates an AWS CloudFront distribution for serving a static website from S3 with custom domain support and SSL/TLS encryption.

## Overview

CloudFront is AWS's Content Delivery Network (CDN) service that distributes content globally through edge locations. This module solves a critical limitation: **S3 bucket names must be globally unique**, but when using CloudFront, the bucket name doesn't need to match the domain name. CloudFront acts as a proxy, allowing you to use any available bucket name while still serving content on your custom domain with HTTPS.

## Why CloudFront Instead of Direct S3?

### Problem with Direct S3 Website Hosting
When using S3 website hosting with Route53 alias records, AWS requires the bucket name to **exactly match** the domain name. For `beto-najera.com`, you need a bucket named `beto-najera.com`. If that bucket name is taken globally (by anyone in any AWS account), you're stuck.

### Solution: CloudFront
CloudFront decouples the bucket name from the domain name:
- Bucket can be named anything (e.g., `beto-najera.com-site`)
- CloudFront distribution serves content on your custom domain
- Adds HTTPS, compression, and global caching as bonuses

## Resources Created

### 1. `aws_cloudfront_origin_access_control` - Origin Access Control (OAC)

Controls how CloudFront accesses the S3 bucket.

**Why?**
- Modern replacement for Origin Access Identity (OAI)
- Uses SigV4 signing for enhanced security
- Required for CloudFront to access S3 securely
- Prevents direct S3 access (users must go through CloudFront)

**Configuration:**
```terraform
origin_access_control_origin_type = "s3"
signing_behavior                  = "always"
signing_protocol                  = "sigv4"
```

**Why these settings?**
- `origin_type = "s3"`: Optimized for S3 origins
- `signing_behavior = "always"`: All requests signed (maximum security)
- `signing_protocol = "sigv4"`: Modern AWS signature protocol

### 2. `aws_cloudfront_distribution` - CDN Distribution

The main CloudFront distribution that serves your website globally.

#### Key Configuration Decisions

**Aliases (Custom Domains):**
```terraform
aliases = var.create_www_alias ? [
  var.domain_name,
  "www.${var.domain_name}"
] : [var.domain_name]
```

**Why?** Allows serving content on your custom domain(s). Without aliases, users would access via CloudFront's default domain (`d111111abcdef8.cloudfront.net`).

**Origin Configuration:**
```terraform
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
```

**Why custom_origin_config instead of s3_origin_config?**
- We're using the **S3 website endpoint** (not the REST API endpoint)
- S3 website endpoints only support HTTP (no HTTPS)
- `origin_protocol_policy = "http-only"`: CloudFront → S3 uses HTTP
- Users still get HTTPS (CloudFront → User uses HTTPS)
- This enables S3's built-in index.html routing and error handling

**Default Cache Behavior:**
```terraform
default_cache_behavior {
  allowed_methods  = ["GET", "HEAD", "OPTIONS"]
  cached_methods   = ["GET", "HEAD"]
  target_origin_id = "S3-${var.s3_bucket_name}"

  viewer_protocol_policy = "redirect-to-https"
  min_ttl                = 0
  default_ttl            = 3600      # 1 hour
  max_ttl                = 86400     # 24 hours
  compress               = true
}
```

**Why these settings?**
- `allowed_methods`: Static website only needs GET, HEAD, OPTIONS
- `viewer_protocol_policy = "redirect-to-https"`: Force HTTPS (security best practice)
- `default_ttl = 3600`: Cache for 1 hour (balance between performance and freshness)
- `compress = true`: Automatically compress text files (HTML, CSS, JS) for faster loading

**Custom Error Responses (SPA Support):**
```terraform
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
```

**Why?**
Critical for Single Page Applications (SPAs) like Nuxt.js, Vue.js, React:
- SPAs use client-side routing (e.g., `/about`, `/contact`)
- These paths don't exist as actual files in S3
- S3 returns 404 for `/about` (file doesn't exist)
- CloudFront intercepts 404/403, returns `index.html` instead
- SPA's JavaScript handles the routing client-side

**Without this:** Direct navigation to `/about` would show 404 error.
**With this:** Direct navigation works perfectly.

**SSL/TLS Certificate:**
```terraform
viewer_certificate {
  acm_certificate_arn      = var.certificate_arn
  ssl_support_method       = "sni-only"
  minimum_protocol_version = "TLSv1.2_2021"
}
```

**Why these settings?**
- `acm_certificate_arn`: Uses your custom domain SSL certificate from ACM
- `ssl_support_method = "sni-only"`: Modern, free method (vs dedicated IP which costs $600/month)
- `minimum_protocol_version = "TLSv1.2_2021"`: Only modern, secure protocols (blocks old TLS 1.0/1.1)

**Price Class:**
```terraform
price_class = "PriceClass_100"
```

**Why?**
- `PriceClass_100`: Uses only North America and Europe edge locations
- Significantly cheaper than global (`PriceClass_All`)
- Still provides good coverage for most users
- Can upgrade to `PriceClass_200` (+ Asia) or `PriceClass_All` (global) if needed

## Key Design Decisions

### Using S3 Website Endpoint (Not REST API Endpoint)

**Decision:** Origin uses `s3-website.REGION.amazonaws.com` endpoint

**Reasons:**
1. **Index Document Support**: S3 website hosting automatically serves `index.html` for directory requests
2. **Error Document Support**: Can configure custom error pages
3. **Redirects**: S3 website hosting supports routing rules
4. **Client-Side Routing**: Works better with SPAs

**Trade-off:** Must use `custom_origin_config` (not `s3_origin_config`), but benefits outweigh this complexity.

### SPA Error Handling at CloudFront Level

**Decision:** CloudFront converts 404/403 to 200 + index.html

**Reasons:**
1. **Client-Side Routing**: SPAs need to handle routing in JavaScript
2. **Direct URL Access**: Users can bookmark and share deep links
3. **Better UX**: No flash of error page before SPA loads
4. **SEO**: Search engines can crawl JavaScript-rendered pages

### SNI-Only SSL

**Decision:** Use SNI (Server Name Indication) instead of dedicated IP

**Reasons:**
1. **Cost**: Free vs $600/month for dedicated IP
2. **Browser Support**: 99.9% of browsers support SNI (IE6 on Windows XP is the exception)
3. **Modern Standard**: Industry standard for years

### Compression Enabled

**Decision:** Automatically compress responses

**Reasons:**
1. **Performance**: Reduces bandwidth by 70%+ for text files
2. **Faster Load Times**: Smaller files = faster downloads
3. **Cost Savings**: Less data transfer = lower CloudFront costs
4. **No Downsides**: Browsers automatically decompress

## Usage

```hcl
module "cloudfront" {
  source = "./modules/cloudfront"

  project_name        = "my-project"
  domain_name         = "example.com"
  s3_bucket_name      = "example.com-site"
  s3_website_endpoint = "example.com-site.s3-website.us-east-1.amazonaws.com"
  certificate_arn     = module.acm_cloudfront.certificate_arn
  create_www_alias    = true
}
```

**Important:** The ACM certificate must be in `us-east-1` region (CloudFront requirement).

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Project name for resource naming | string | - | yes |
| domain_name | Primary domain name for the distribution | string | - | yes |
| s3_bucket_name | Name of the S3 bucket containing the website | string | - | yes |
| s3_website_endpoint | S3 website endpoint (without http://) | string | - | yes |
| certificate_arn | ARN of the ACM certificate (must be in us-east-1) | string | - | yes |
| create_www_alias | Whether to create www subdomain alias | bool | true | no |

## Outputs

| Name | Description |
|------|-------------|
| distribution_id | CloudFront distribution ID (use for cache invalidation) |
| distribution_arn | ARN of the CloudFront distribution |
| distribution_domain_name | CloudFront domain (e.g., d111111abcdef8.cloudfront.net) |
| distribution_hosted_zone_id | CloudFront hosted zone ID for Route53 alias records |

## Post-Deployment

### Cache Invalidation

After updating files in S3, invalidate the CloudFront cache:

```bash
aws cloudfront create-invalidation \
  --distribution-id YOUR_DISTRIBUTION_ID \
  --paths "/*"
```

**Why?** CloudFront caches files based on TTL. Invalidation forces immediate refresh.

**Cost:** First 1,000 invalidation paths per month are free, then $0.005 per path.

### Deployment Time

CloudFront distributions take **15-20 minutes** to deploy initially. This is normal and unavoidable.

**Why?** AWS propagates configuration to hundreds of edge locations worldwide.

## Troubleshooting

### Distribution Shows "In Progress"
**Solution:** Wait 15-20 minutes. This is normal for initial deployment.

### 403 Forbidden Error
**Solutions:**
1. Check S3 bucket policy allows public read
2. Verify S3 website hosting is enabled
3. Ensure `index.html` exists in bucket

### 404 Not Found Error
**Solutions:**
1. Check file exists in S3 bucket
2. Verify custom error response is configured (for SPAs)
3. Check S3 website endpoint is correct in CloudFront origin

### SSL Certificate Error
**Solutions:**
1. Verify certificate is in `us-east-1` region
2. Check certificate covers both domain and www subdomain
3. Ensure certificate is validated and issued (not pending)

## Security Considerations

- ✅ HTTPS enforced (`redirect-to-https`)
- ✅ Modern TLS only (TLS 1.2+)
- ✅ Origin Access Control prevents direct S3 access
- ✅ SNI for cost-effective SSL
- ✅ Compression reduces bandwidth (potential DoS mitigation)
