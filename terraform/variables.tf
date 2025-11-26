variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "beto-mn-site"
}

variable "domain_name" {
  description = "Domain name for the website (must be registered in Route53)"
  type        = string
}
