output "dns_record" {
  description = "The DNS record created for the domain"
  value       = aws_route53_record.static_site_record.fqdn
}
