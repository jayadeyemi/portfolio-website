resource "random_integer" "random_id" {
  min = 1000
  max = 9999
  lifecycle {
    prevent_destroy = true 
  }
}

# ACM, CloudFront, and S3 Bucket + Policies
module "frontend" {
  source                          = "./modules/frontend"
  acm_certificate_name            = local.acm_certificate_name
  cloudfront_aliases              = local.cloudfront_aliases
  cloudfront_origin_id            = local.cloudfront_origin_id
  cloudfront_distribution_comment = local.cloudfront_distribution_comment
  cloudfront_price_class          = var.cloudfront_price_class
  frontend_bucket_name            = local.frontend_bucket_name
  oac_name                        = local.oac_name
  project_name                    = var.project_name
  route53_hosted_zone_id          = data.aws_route53_zone.existing.zone_id
  subject_alternative_names       = local.cloudfront_aliases
  website_alternative_names       = var.website_alternative_names
  website_domain_name             = var.website_domain_name

  providers                       = {
    aws.us_east_1 = aws.us_east_1
  }
}

# 
# module "decouplers" {
#   source                = "./modules/decouplers"
#   eventbridge_rule_name = local.eventbridge_rule_name
#   lambda_function_arn   = module.backend.lambda_function_arn
#   lambda_function_name  = module.backend.lambda_function_name
# }

module "backend" {
  source                       = "./modules/backend"
  lambda_runtime               = var.lambda_runtime
  lambda_function_name         = local.lambda_function_name
  lambda_environment_variables = local.lambda_environment_variables
  lambda_zip_path              = local.lambda_zip_path
  lambda_role_name             = local.lambda_role_name
  lambda_policy_name           = local.lambda_policy_name
  frontend_bucket_arn          = module.frontend.frontend_bucket_arn
  spotify_secret_arn           = module.secrets.spotify_secret_arn
}



module "uploader" {
  source                      = "./modules/uploader"
  s3_files_map                = local.s3_files_map
  s3_bucket_id                = module.frontend.frontend_bucket_id
}

module "secrets" {
  source                      = "./modules/secrets"
  secrets_id                  = data.aws_secretsmanager_secret.spotify_secret.id
  spotify_secrets             = local.lambda_environment_variables
}

# module "triggers" {
#   source                      = "./modules/trigger"
#   eventbridge_rule_name       = local.eventbridge_rule_name
#   lambda_function_name        = module.backend.lambda_function_name
#   lambda_function_arn         = module.backend.lambda_function_arn
  
# }