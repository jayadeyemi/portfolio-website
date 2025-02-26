
resource "random_integer" "random_id" {
  min = 1000
  max = 9999
  lifecycle {
    prevent_destroy = true 
  }
}

locals {
  resource_prefix                 = "${var.project_name}-${var.environment}"
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
  lambda_environment_variables    = {
    SPOTIFY_CLIENT_ID     = var.spotify_client_id
    SPOTIFY_CLIENT_SECRET = var.spotify_client_secret
  }
  spotify_js_content              = templatefile("${var.frontend_path}${var.spotify_js_template}", {
    cloudfront_domain = module.cloudfront.cloudfront_domain_name,
    api_id            = module.api_gateway.rest_api_id,
    region            = var.aws_region
  })
  s3_source_list = [
    var.home_html,
    var.home_css,
    var.spotify_html,
    var.spotify_css,
    var.spotify_js,
    local_file.script_file.filename
  ]
  s3_files_list = [
    for file in local.s3_source_list : {
      s3_key = file
      source = "${var.frontend_path}${file}"
      content_type = (
        endswith(file, ".html") ? "text/html" :
        endswith(file, ".css")  ? "text/css"  :
        endswith(file, ".js")   ? "application/javascript" :
        "application/octet-stream"
      )
    }
  ]
}

#   s3_files = {
#     static_index = {
#       s3_key        = "index.html"
#       source        = "../app/static/index.html"
#       content_type  = "text/html"
#     },
#     static_css  = {
#       s3_key        = "styles.css"
#       source        = "../app/static/styles.css"
#       content_type  = "text/css"
#     },
#     interactive_html = {
#       s3_key       = "interactive/index.html"
#       source       = "../app/interactive/interactive.html"
#       content_type = "text/html"
#     },
#     interactive_css = {
#       s3_key       = "interactive/styles.css"
#       source       = "../app/interactive/styles.css"
#       content_type = "text/css"
#     },
#     interactive_js = {
#       s3_key       = "interactive/scripts/main.js"
#       source       = local_file.script_file.filename
#       content_type = "application/javascript"
#     }
#   }
# }

resource "local_file" "script_file" {
  content  = local.spotify_js_content
  filename = "${var.frontend_path}${var.spotify_js}"
}
