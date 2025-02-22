
resource "random_integer" "random_id" {
  min = 1000
  max = 9999
}

locals {
  resource_prefix      = "${var.project_name}-${var.environment}"
  api_gateway_name     = "${local.resource_prefix}-api-gateway"
  cloudfront_origin_id = "${local.resource_prefix}-s3-bucket-${random_integer.random_id.result}"
  iam_role_name        = "${local.resource_prefix}-iam-role"
  lambda_function_name = "${local.resource_prefix}-lambda-function"
  sns_topic_name       = "${local.resource_prefix}-sns-topic"
  lambda_py_zip        = "../lambda/lambda_function.zip"
  website_domain_name  = "www.babasanmiadeyemiportfolio.com"
  s3_bucket_name       = "${local.resource_prefix}-bucket-${random_integer.random_id.result}"

  interactive_index = templatefile("../app/interactive/interactive.html.tmpl", {
    cloudfront_domain = data.aws_cloudfront_distribution.portfolio_cf.domain_name
  })
  s3_files = {
    static_index = {
      s3_key       = "static/index.html"
      source       = "../app/static/index.html"
      content_type = "text/html"
    },
    static_css = {
      s3_key       = "static/styles.css"
      source       = "../app/static/styles.css"
      content_type = "text/css"
    },
    interactive_html = {
      s3_key       = "interactive/interactive.html"
      source       = local.interactive_index
      content_type = "text/html"
    },
    interactive_css = {
      s3_key       = "interactive/styles.css"
      source       = "../app/interactive/styles.css"
      content_type = "text/css"
    },
    interactive_js = {
      s3_key       = "interactive/scripts/main.js"
      source       = "../app/interactive/scripts/main.js"
      content_type = "application/javascript"
    }
  }
}