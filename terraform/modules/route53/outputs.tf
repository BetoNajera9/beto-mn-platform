output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "hosted_zone_name_servers" {
  description = "Name servers for the hosted zone"
  value       = aws_route53_zone.main.name_servers
}

output "website_record_name" {
  description = "The DNS record name for the website"
  value       = aws_route53_record.website.name
}

output "website_record_fqdn" {
  description = "The fully qualified domain name for the website"
  value       = aws_route53_record.website.fqdn
}

output "root_record_fqdn" {
  description = "The fully qualified domain name for the root domain (if created)"
  value       = var.create_www_subdomain ? aws_route53_record.root[0].fqdn : null
}
