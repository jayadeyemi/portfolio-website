resource "aws_lambda_function" "data_processor" {
  function_name    = var.lambda_function_name
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.8"
  role             = var.lambda_role_arn
  filename         = var.lambda_py_zip
  source_code_hash = filebase64sha256(var.lambda_py_zip)
  timeout          = 300
  environment {
    variables = {
      S3_BUCKET_NAME = var.s3_bucket_name
      SECRET_NAME    = var.portfolio_secret_name
    }
  }
}

# Grant API Gateway permission to invoke the Lambda function
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_rest_api_arn}/*/*"
}