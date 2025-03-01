
# For text-based files (including .tmpl, .html, .css, and .js)
resource "local_file" "files_text" {
  for_each = { for file, type in local.files_map : file => file if type == "text" }

  # For .tmpl files, remove the extension from the filename.
  filename = "${var.frontend_path}${endswith(each.value, ".tmpl") ? replace(each.value, "\\.tmpl$", "") : each.value}"

  content = endswith(each.value, ".tmpl") ? templatefile(
    "${var.frontend_path}${each.value}",
    local.js_variables
  ) : file("${var.frontend_path}${each.value}")
}

# For binary files (any file not classified as text)
resource "local_file" "files_binary" {
  for_each = { for file, type in local.files_map : file => file if type == "binary" }

  filename       = "${var.frontend_path}${each.value}"
  content_base64 = filebase64("${var.frontend_path}${each.value}")
}

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

  files_map = {
    for file in var.s3_file_list : file => (
      endswith(file, ".tmpl") || endswith(file, ".html") || endswith(file, ".css") || endswith(file, ".js")
      ? "text" : "binary"
    )
  }
  
  js_variables                    = {
      cloudfront_domain = module.cloudfront.cloudfront_distribution_domain_name
      api_id            = local.lambda_function_name
      region            = var.aws_region
    }

  lambda_environment_variables    = {
    SPOTIFY_CLIENT_ID     = var.spotify_client_id
    SPOTIFY_CLIENT_SECRET = var.spotify_client_secret
  }

  s3_files_map                    = {
    for file in var.s3_file_list : file => {
      s3_key       = file
      source       = "${var.frontend_path}${file}"
      content_type = (
        endswith(file, ".html") ? "text/html" :
        endswith(file, ".css")  ? "text/css"  :
        endswith(file, ".js")   ? "application/javascript" :
        endswith(file, ".jpg")  ? "image/jpeg" :
        "application/octet-stream"
      )
    }
  }
}


