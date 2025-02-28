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
  bucket_name                     = "${local.resource_prefix}-bucket-${random_integer.random_id.result}"
  cloudfront_aliases              = concat([var.website_domain_name], var.website_alternative_names)
    s3_source_list = concat(var.s3_file_list,[local_file.script_file.filename])


  lambda_environment_variables    = {
    SPOTIFY_CLIENT_ID     = var.spotify_client_id
    SPOTIFY_CLIENT_SECRET = var.spotify_client_secret
  }

  spotify_js_content              = templatefile("${var.frontend_path}${var.spotify_js_template}", {
    cloudfront_domain = module.cloudfront.cloudfront_distribution_domain_name
    api_id            = local.lambda_function_name
    region            = var.aws_region
  })

  s3_files_map = {
    for file in local.s3_source_list : file => {
      s3_key = file
      source = "${var.frontend_path}${file}"
      content_type = (
        endswith(file, ".html") ? "text/html" :
        endswith(file, ".css")  ? "text/css"  :
        endswith(file, ".js")   ? "application/javascript" :
        "application/octet-stream"
      )
    }
  }
}

resource "local_file" "script_file" {
  content  = local.spotify_js_content
  filename = "${var.frontend_path}${var.spotify_js_template}"
}
