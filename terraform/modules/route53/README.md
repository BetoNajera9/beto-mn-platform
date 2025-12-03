# Route53 Module

This module manages DNS configuration for both website and API endpoints using AWS Route53.

## Overview

The Route53 module creates a hosted zone and configures DNS records to route traffic to your S3 website and API Gateway. It handles domain delegation and supports optional www subdomain configuration.

## Resources Created

### 1. `aws_route53_zone` - Hosted Zone

Creates the DNS hosted zone for your domain.

**Why?**
- Acts as the DNS authority for your domain
- Contains all DNS records for the domain
- Provides name servers that must be configured with your domain registrar

**Important:** After creation, you must update your domain's name servers (at the registrar) to point to the Route53 name servers.

### 2. `aws_route53_record.website` - Website DNS Record

Creates an A record (ALIAS) pointing to the S3 website endpoint.

**Why?**
- Routes `example.com` (or `www.example.com`) to your S3 bucket
- Uses ALIAS record (AWS-specific) instead of CNAME for better performance
- No additional cost for ALIAS queries
- `evaluate_target_health = true`: AWS checks if S3 endpoint is healthy

**Conditional Logic:**
```terraform
name = var.create_www_subdomain ? "www.${var.domain_name}" : var.domain_name
```
- If `create_www_subdomain = false` → Creates record for `example.com`
- If `create_www_subdomain = true` → Creates record for `www.example.com`

### 3. `aws_route53_record.root` - Root Domain Record (Optional)

Creates an additional A record for the root domain when using www subdomain.

**Why?**
- Only created when `create_www_subdomain = true`
- Ensures both `example.com` AND `www.example.com` work
- Both point to the same S3 bucket
- `evaluate_target_health = false`: No health checks needed for redundancy

**Use Case:**
```
User types: example.com → Routes to S3 ✅
User types: www.example.com → Routes to S3 ✅
```

### 4. `aws_route53_record.api` - API Subdomain Record (Optional)

Creates an A record for the API subdomain pointing to API Gateway.

**Why?**
- Routes `api-contact.example.com` to API Gateway
- Only created when `api_gateway_domain != null`
- Separate subdomain keeps API and website concerns separated
- Uses regional API Gateway endpoint for lower latency

**Conditional Creation:**
```terraform
count = var.api_gateway_domain != null ? 1 : 0
```
Only creates if API Gateway information is provided (optional module usage).

## Key Design Decisions

### Resource (Not Data Source)
**Decision:** Uses `resource` instead of `data` for hosted zone

**Reason:**
- Domain purchased but hosted zone not yet created
- Terraform manages the complete DNS infrastructure
- Ensures hosted zone configuration is tracked in IaC

### ALIAS Records (Not CNAME)
**Decision:** Uses ALIAS records for AWS services

**Reason:**
- ALIAS works at zone apex (`example.com`), CNAME doesn't
- No additional DNS query costs
- Better performance (AWS-optimized routing)
- Supports health checks

### Optional Resources
**Decision:** Uses `count` for optional records

**Reason:**
- www subdomain not always needed
- API may not exist yet
- Module flexibility for different architectures
- Pay only for what you use

## Usage

### Basic Setup (Website Only)
```terraform
module "route53" {
  source = "./modules/route53"

  domain_name          = "example.com"
  environment          = "prod"
  s3_website_domain    = module.s3.website_domain
  s3_hosted_zone_id    = module.s3.website_hosted_zone_id
  create_www_subdomain = false
}
```

### With API Subdomain
```terraform
module "route53" {
  source = "./modules/route53"

  domain_name           = "example.com"
  environment           = "prod"
  s3_website_domain     = module.s3.website_domain
  s3_hosted_zone_id     = module.s3.website_hosted_zone_id
  create_www_subdomain  = false
  api_subdomain         = "api-contact.example.com"
  api_gateway_domain    = module.api.regional_domain_name
  api_gateway_zone_id   = module.api.regional_zone_id
}
```

## Post-Deployment Steps

### 1. Get Name Servers
After `terraform apply`, get the name servers:
```bash
terraform output route53_name_servers
```

Output example:
```
[
  "ns-1234.awsdns-56.org",
  "ns-789.awsdns-12.co.uk",
  "ns-345.awsdns-67.com",
  "ns-890.awsdns-34.net"
]
```

### 2. Update Domain Registrar
Go to your domain registrar (where you bought the domain) and update the name servers to match the Route53 name servers.

### 3. Wait for Propagation
DNS propagation can take 24-48 hours, but often completes in a few hours.

### 4. Verify DNS
```bash
dig example.com
nslookup example.com
```

## DNS Resolution Flow

```
User types: example.com
    ↓
Browser queries DNS
    ↓
Domain registrar → Route53 name servers
    ↓
Route53 hosted zone → A record (ALIAS)
    ↓
ALIAS points to S3 website endpoint
    ↓
Browser connects to S3
    ↓
Website loads
```

## Important Notes

### Name Server Configuration
**Critical:** You MUST update your domain's name servers at the registrar. The Route53 hosted zone won't work until the domain delegation is complete.

### Propagation Time
DNS changes take time to propagate globally. Be patient after making changes.

### S3 Bucket Naming
The S3 bucket name must exactly match the domain name in the DNS record for routing to work properly.

## Troubleshooting

### DNS Not Resolving
1. Verify name servers are updated at registrar
2. Wait for DNS propagation (up to 48 hours)
3. Check Route53 hosted zone has correct records
4. Use `dig` or `nslookup` to debug

### Website Not Loading
1. Verify S3 bucket name matches domain
2. Check S3 bucket policy allows public access
3. Ensure S3 website hosting is enabled
4. Test S3 website endpoint directly first

## Outputs

- `hosted_zone_id` - For other resources to use
- `hosted_zone_name_servers` - For domain registrar configuration
- `website_record_fqdn` - Fully qualified domain name for website
- `root_record_fqdn` - Root domain FQDN (if created)
