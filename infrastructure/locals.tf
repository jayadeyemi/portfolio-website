
locals {
  resource_prefix                 = "${var.project_name}"
  lambda_zip_path                 = "${var.lambda_path}${var.lambda_filename}"
  lambda_role_name                = "${local.resource_prefix}-lambda-role"
  lambda_policy_name              = "${local.resource_prefix}-lambda-policy"
  oac_name                        = "${local.resource_prefix}-oac"
  cloudfront_origin_id            = "${local.resource_prefix}-s3-origin-${random_integer.random_id.result}"
  cloudfront_distribution_comment = "${local.resource_prefix} CloudFront Distribution"
  acm_certificate_name            = "${local.resource_prefix}-acm-cert"
  cloudfront_distribution_arn     = "${local.resource_prefix}-cloudfront-dist-${random_integer.random_id.result}"
  iam_role_name                   = "${local.resource_prefix}-iam-role"
  lambda_function_name            = "${local.resource_prefix}-lambda-function"
  frontend_bucket_name            = "${local.resource_prefix}-bucket-${random_integer.random_id.result}"
  cloudwatch_event_rule_name      = "${local.resource_prefix}-cloudwatch-event-rule"
  cloudfront_aliases              = concat([var.website_domain_name], var.website_alternative_names)

  files_map = {
    for file in var.s3_file_list : file =>
      endswith(file, ".tmpl") ||
      endswith(file, ".html") ||
      endswith(file, ".css")  ||
      endswith(file, ".js")
      ? "text" : "binary"
  }

  processed_content = {
    for file in var.s3_file_list : file =>
      endswith(file, ".tmpl") ? 
        templatefile("${path.module}/${var.frontend_path}${file}", local.js_variables) :
      (
        local.files_map[file] == "binary" ?
          data.local_file.files[file].content_base64 :
          data.local_file.files[file].content
      )
  }
  js_variables                    = {
      cloudfront_domain = module.frontend.cloudfront_distribution_domain_name
      api_id            = local.lambda_function_name
      region            = var.aws_region
    }

  lambda_environment_variables    = {
    SPOTIFY_CLIENT_ID     = var.spotify_client_id
    SPOTIFY_CLIENT_SECRET = var.spotify_client_secret
  }

  s3_files_map = {
    for file, classification in local.files_map :
    file => {
      # The key that will go into S3
      s3_key = endswith(file, ".tmpl") ? replace(file, ".tmpl", "") : file

      content_type = (
        endswith(file, ".html") ? "text/html" :
        endswith(file, ".css")  ? "text/css" :
        endswith(file, ".js")   ? "application/javascript" :
        endswith(file, ".jpg")  ? "image/jpeg" :
        "application/octet-stream"
      )

      # If .tmpl, apply templatefile() directly
      # If text & not .tmpl, use data.local_file.files[file].content
      # If binary, use data.local_file.files[file].content_base64

      processed_content = local.processed_content[file]
      
    }
  }
}


