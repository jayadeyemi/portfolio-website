
# API Gateway REST API
resource "aws_api_gateway_rest_api" "data_api" {
  name = var.api_gateway_name
}

# Create a resource endpoint (e.g. /data)
resource "aws_api_gateway_resource" "data_resource" {
  rest_api_id = aws_api_gateway_rest_api.data_api.id
  parent_id   = aws_api_gateway_rest_api.data_api.root_resource_id
  path_part   = "data"
}

# Define a GET method for the /data resource
resource "aws_api_gateway_method" "get_data" {
  rest_api_id   = aws_api_gateway_rest_api.data_api.id
  resource_id   = aws_api_gateway_resource.data_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# Integrate the GET method with the Lambda function (AWS_PROXY)
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.data_api.id
  resource_id             = aws_api_gateway_resource.data_resource.id
  http_method             = aws_api_gateway_method.get_data.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_arn
}

# Deploy the API Gateway
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.data_api.id
    triggers = {
    redeployment = sha1(jsonencode([
    aws_api_gateway_resource.data_resource.id,
    aws_api_gateway_method.get_data.id,
    aws_api_gateway_integration.lambda_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.data_api.id
  stage_name    = "prod"
  description   = "Production stage"
  variables = {
    lambda_function_name = var.lambda_function_name
  }
}

