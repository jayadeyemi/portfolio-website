module "api_gateway" {
  source                        = "./modules/api_gateway"
  api_gateway_name              = local.api_gateway_name
  lambda_function_name          = local.lambda_function_name
  lambda_function_arn           = module.lambda.lambda_function_arn
}

module "cloudfront" {
  source                        = "./modules/cloudfront"
  cloudfront_origin_domain_name = module.s3.bucket_regional_domain_name
  cloudfront_origin_id          = local.cloudfront_origin_id
}

module "iam" {
  source                        = "./modules/iam"
  iam_role_name                 = local.iam_role_name
  s3_bucket_arn                 = module.s3.s3_bucket_arn
}

module "lambda" {
  source                        = "./modules/lambda"
  lambda_function_name          = local.lambda_function_name
  lambda_py_zip                 = local.lambda_py_zip
  lambda_role_arn               = module.iam.lambda_role_arn 
  api_gateway_rest_api_arn      = module.api_gateway.rest_api_id
  aws_region                    = var.aws_region
  sns_topic_name                = local.sns_topic_name
  s3_bucket_name                = module.s3.bucket_name

  }
  
module "route53" {
  source                        = "./modules/route53"
  website_domain_name           = var.website_domain_name
  cloudfront_domain_name        = module.cloudfront.cloudfront_domain_name
  cloudfront_hosted_zone_id     = module.cloudfront.cloudfront_hosted_zone_id
}

module "s3" {
  source                        = "./modules/s3"
  s3_bucket_name                = local.s3_bucket_name
  s3_files                      = local.s3_files
  origin_access_identity        = module.cloudfront.cloudfront_oai_iam_arn
}

module "sns" {
  source                        = "./modules/sns"
  sns_topic_name                = local.sns_topic_name
  lambda_function_name          = local.lambda_function_name
  sns_subscription_email        = var.sns_subscription_email
}