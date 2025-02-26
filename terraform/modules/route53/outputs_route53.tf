output "route53_record_fqdn" {
  description = "The DNS record created for the domain"
  value       = aws_route53_record.static_site_record.fqdn
}