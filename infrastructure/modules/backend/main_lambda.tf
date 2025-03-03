resource "aws_lambda_function" "data_processor" {
  function_name    = var.lambda_function_name
  handler          = "lambda_function.lambda_handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.data_processor_role.arn
  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  timeout          = 300
  environment {
    variables = var.lambda_environment_variables
  }
}

# IAM role for Lambda execution
resource "aws_iam_role" "data_processor_role" {
  name = var.lambda_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM policy for Lambda Role
resource "aws_iam_role_policy" "data_processor_policy" {
  name = var.lambda_policy_name
  role = aws_iam_role.data_processor_role.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = var.frontend_bucket_arn 
      },
      {
        Effect   = "Allow",
        Action   = [ "secretsmanager:GetSecretValue" ],
        Resource = var.spotify_secret_arn
      }
    ]
  })
}