data "aws_secretsmanager_secret" "spotify_secret" {
  name = var.secrets_manager_secret_name
}

# Route 53 DNS record to point your domain to CloudFront
data "aws_route53_zone" "existing" {
  name         = "${var.website_domain_name}."
  private_zone = false
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${var.lambda_path}${var.lambda_file}"
  output_path = local.lambda_zip_path
}