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
  source_file = "${var.backend_path}${var.lambda_template}"
  output_path = local.lambda_zip_path
}

data "local_file" "files" {
  # use s3_file_list to get the list of files
  for_each = { for file in var.s3_file_list : file => file }
  filename = "${path.module}/${var.frontend_path}${each.value}"
}
