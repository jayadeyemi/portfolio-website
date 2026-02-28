
locals {
  bucket_suffix                   = var.project_suffix
  resource_prefix                 = "${var.project_name}"
  lambda_zip_path                 = "${var.backend_path}${var.lambda_filename}"
  lambda_role_name                = "${local.resource_prefix}-lambda-role"
  lambda_policy_name              = "${local.resource_prefix}-lambda-policy"
  oac_name                        = "${local.resource_prefix}-oac"
  cloudfront_origin_id            = "${local.resource_prefix}-s3-origin-${local.bucket_suffix}"
  cloudfront_distribution_comment = "${local.resource_prefix} CloudFront Distribution"
  acm_certificate_name            = "${local.resource_prefix}-acm-cert"
  cloudfront_distribution_arn     = "${local.resource_prefix}-cloudfront-dist-${local.bucket_suffix}"
  iam_role_name                   = "${local.resource_prefix}-iam-role"
  lambda_function_name            = "${local.resource_prefix}-lambda-function"
  frontend_bucket_name            = "${local.resource_prefix}-bucket-${local.bucket_suffix}"
  cloudwatch_event_rule_name      = "${local.resource_prefix}-cloudwatch-event-rule"
  cloudfront_aliases              = concat([var.website_domain_name], var.website_alternative_names)

  spotify_credentials             = {
    SPOTIFY_CLIENT_ID     = var.spotify_client_id
    SPOTIFY_CLIENT_SECRET = var.spotify_client_secret
  }

  files_map                       = {
    for file in var.s3_file_list : file =>
      endswith(file, ".tmpl") ||
      endswith(file, ".html") ||
      endswith(file, ".css")  ||
      endswith(file, ".js")
      ? "text" : "binary"
  }

  processed_content               = {
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

  spotify_redirect_uri            = "https://${var.website_domain_name}/api/auth/callback"

  lambda_environment_variables    = {
    S3_BUCKET_NAME         = local.frontend_bucket_name
    SECRET_NAME            = var.secrets_manager_secret_name
    KMS_KEY_ID             = module.kms.kms_key_id
    USERS_TABLE            = module.dynamodb.users_table_name
    TOKENS_TABLE           = module.dynamodb.spotify_tokens_table_name
    SESSIONS_TABLE         = module.dynamodb.sessions_table_name
    INSIGHTS_TABLE         = module.dynamodb.insights_table_name
    ACCESS_REQUESTS_TABLE  = module.dynamodb.access_requests_table_name
    PLAY_HISTORY_TABLE     = module.dynamodb.play_history_table_name
    WEBSITE_DOMAIN         = var.website_domain_name
    SPOTIFY_REDIRECT_URI   = local.spotify_redirect_uri
    OWNER_SPOTIFY_USER_ID  = var.owner_spotify_user_id
    POLICY_VERSION         = var.policy_version
    ADMIN_EMAIL            = var.admin_email
    SES_FROM_EMAIL         = "noreply@${var.website_domain_name}"
  }

  # Single hash of all file contents — used to trigger CloudFront invalidation.
  # Computed locally so the value is stable between plan and apply.
  content_hash = md5(join(",", [
    for file in sort(keys(local.processed_content)) : md5(local.processed_content[file])
  ]))

  s3_files_map                    = {
    for file, classification in local.files_map :
    file => {
      # The key that will go into S3
      s3_key = endswith(file, ".tmpl") ? replace(file, ".tmpl", "") : file

      content_type      = (
        endswith(file, ".html")   ? "text/html" :
        endswith(file, ".css")    ? "text/css" :
        endswith(file, ".js")     ? "application/javascript" :
        endswith(file, ".js.tmpl")? "application/javascript" :
        endswith(file, ".jpg")    ? "image/jpeg" :
        "application/octet-stream"
      )

      # If .tmpl, apply templatefile() directly
      # If text & not .tmpl, use data.local_file.files[file].content
      # If binary, use data.local_file.files[file].content_base64

      processed_content = local.processed_content[file]
      classification    = classification
      
    }
  }
}


