variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the CloudFront distribution"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket containing the website"
  type        = string
}

variable "s3_website_endpoint" {
  description = "S3 website endpoint (without http://)"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for the domain"
  type        = string
}

variable "create_www_alias" {
  description = "Whether to create www subdomain alias"
  type        = bool
  default     = true
}
