
resource "random_integer" "random_id" {
  min = 1000
  max = 9999
  lifecycle {
    prevent_destroy = true 
  }
}

locals {
  resource_prefix      = "${var.project_name}-${var.environment}"
  api_gateway_name     = "${local.resource_prefix}-api-gateway"
  cloudfront_origin_id = "${local.resource_prefix}-s3-bucket-${random_integer.random_id.result}"
  iam_role_name        = "${local.resource_prefix}-iam-role"
  lambda_function_name = "${local.resource_prefix}-lambda-function"
  sns_topic_name       = "${local.resource_prefix}-sns-topic"
  lambda_py_zip        = "../lambda/lambda_function.zip"
  website_domain_name  = var.website_domain_name
  s3_bucket_name       = "${local.resource_prefix}-bucket-${random_integer.random_id.result}"
  
  interactive_js       = templatefile("../app/interactive/scripts/main.js.tmpl", {
    cloudfront_domain     = module.cloudfront.cloudfront_domain_name,
    api_id                = module.api_gateway.rest_api_id,
    region                = var.aws_region
  })
  
  s3_files = {
    static_index = {
      s3_key              = "index.html"
      source              = "../app/static/index.html"
      content_type        = "text/html"
    },
    static_css   = {
      s3_key              = "styles.css"
      source              = "../app/static/styles.css"
      content_type        = "text/css"
    },
    interactive_html = {
      s3_key              = "interactive/index.html"
      source              = "../app/interactive/interactive.html"
      content_type        = "text/html"
    },
    interactive_css = {
      s3_key              = "interactive/styles.css"
      source              = "../app/interactive/styles.css"
      content_type        = "text/css"
    },
    interactive_js = {
      s3_key              = "interactive/scripts/main.js"
      source              = local_file.script_file.filename
      content_type        = "application/javascript"
    }
  }
}

resource "local_file" "script_file" {
  content  = local.interactive_js
  filename = "../app/interactive/scripts/main.js"
}
