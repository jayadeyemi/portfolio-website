############################################################################################################
# SES Email Identity — Domain verification for transactional emails
# Cost optimization: SES is pay-per-email ($0.10 per 1,000), zero cost when idle
############################################################################################################

# Domain identity for sending email from @babasanmiadeyemi.com
resource "aws_ses_domain_identity" "domain" {
  domain = var.website_domain_name
}

# DNS verification record — proves domain ownership via Route53
resource "aws_route53_record" "ses_verification" {
  zone_id = var.hosted_zone_id
  name    = "_amazonses.${var.website_domain_name}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.domain.verification_token]
}

# Wait for SES to confirm domain verification
resource "aws_ses_domain_identity_verification" "domain" {
  domain     = aws_ses_domain_identity.domain.id
  depends_on = [aws_route53_record.ses_verification]
}

# DKIM authentication — 3 CNAME records for email deliverability
resource "aws_ses_domain_dkim" "domain" {
  domain = aws_ses_domain_identity.domain.domain
}

resource "aws_route53_record" "ses_dkim" {
  count   = 3
  zone_id = var.hosted_zone_id
  name    = "${aws_ses_domain_dkim.domain.dkim_tokens[count.index]}._domainkey.${var.website_domain_name}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.domain.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# Mail FROM domain — enables proper SPF/DKIM alignment
resource "aws_ses_domain_mail_from" "domain" {
  domain           = aws_ses_domain_identity.domain.domain
  mail_from_domain = "mail.${var.website_domain_name}"
}

# MX record for Mail FROM domain
resource "aws_route53_record" "ses_mail_from_mx" {
  zone_id = var.hosted_zone_id
  name    = "mail.${var.website_domain_name}"
  type    = "MX"
  ttl     = 600
  records = ["10 feedback-smtp.${var.aws_region}.amazonses.com"]
}

# SPF record for Mail FROM domain
resource "aws_route53_record" "ses_mail_from_spf" {
  zone_id = var.hosted_zone_id
  name    = "mail.${var.website_domain_name}"
  type    = "TXT"
  ttl     = 600
  records = ["v=spf1 include:amazonses.com -all"]
}

############################################################################################################
# End of File
############################################################################################################
