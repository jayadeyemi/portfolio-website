resource "aws_lambda_function" "data_processor" {
  function_name    = var.lambda_function_name
  handler          = "lambda_function.lambda_handler"
  runtime          = var.lambda_runtime
  role             = var.lambda_role_arn
  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  timeout          = 300
  environment {
    variables = var.lambda_environment_variables
  }
}

