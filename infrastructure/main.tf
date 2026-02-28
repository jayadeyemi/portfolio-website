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
  subject_alternative_names       = local.cloudfront_aliases
  website_alternative_names       = var.website_alternative_names
  website_domain_name             = var.website_domain_name
  domain_registrant               = var.domain_registrant
  api_origin_domain               = module.api_gateway.api_domain_name

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
  dynamodb_table_arns          = [
    module.dynamodb.users_table_arn,
    module.dynamodb.spotify_tokens_table_arn,
    module.dynamodb.sessions_table_arn,
    module.dynamodb.insights_table_arn,
    module.dynamodb.access_requests_table_arn,
    module.dynamodb.play_history_table_arn,
  ]
  kms_key_arn                  = module.kms.kms_key_arn
  ses_identity_arn             = module.ses.ses_domain_identity_arn
}



module "uploader" {
  source                      = "./modules/uploader"
  s3_files_map                = local.s3_files_map
  s3_bucket_id                = module.frontend.frontend_bucket_id
}

module "secrets" {
  source          = "./modules/secrets"
  secret_name     = var.secrets_manager_secret_name
  project_name    = var.project_name
  spotify_secrets = local.spotify_credentials
}

module "triggers" {
  source                     = "./modules/triggers"
  cloudwatch_event_rule_name = local.cloudwatch_event_rule_name
  lambda_function_name       = module.backend.data_processor_function_name
  lambda_function_arn        = module.backend.data_processor_function_arn
}

# DynamoDB tables for multi-user session/data isolation
module "dynamodb" {
  source       = "./modules/dynamodb"
  project_name = var.project_name
}

# KMS key for encrypting Spotify refresh tokens at rest
module "kms" {
  source       = "./modules/kms"
  project_name = var.project_name
}

# API Gateway HTTP API — routes user requests to Lambda
module "api_gateway" {
  source                    = "./modules/api_gateway"
  project_name              = var.project_name
  lambda_function_name      = module.backend.data_processor_function_name
  lambda_function_invoke_arn = module.backend.data_processor_invoke_arn
  allowed_origins           = [for alias in local.cloudfront_aliases : "https://${alias}"]
}

# SES email identity — domain verification for transactional emails
module "ses" {
  source              = "./modules/ses"
  website_domain_name = var.website_domain_name
  hosted_zone_id      = module.frontend.route53_hosted_zone_id
  aws_region          = var.aws_region
}