# V1 Barebones Infrastructure - NO AUTHENTICATION

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Lambda function for Gemini API calls
resource "aws_lambda_function" "generate_questions" {
  filename         = "../../lambda-functions/deployment.zip"
  function_name    = "${var.project_name}-gemini-handler-v1"
  role            = aws_iam_role.lambda_role.arn
  handler         = "geminiHandler.handler"
  runtime         = "nodejs18.x"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      GEMINI_API_KEY = var.gemini_api_key
    }
  }

  tags = {
    Environment = "v1"
    Purpose     = "MVP"
  }
}

# Simple IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role-v1"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# API Gateway - Simple REST API without authentication
resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.project_name}-api-v1"
  description = "Simple API for Inkra V1 - No Authentication"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Resource - Single endpoint for all actions
resource "aws_api_gateway_resource" "gemini" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "gemini"
}

# API Method - POST
resource "aws_api_gateway_method" "post_questions" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.gemini.id
  http_method   = "POST"
  authorization = "NONE"  # No auth for V1
}

# Lambda Integration
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.gemini.id
  http_method = aws_api_gateway_method.post_questions.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.generate_questions.invoke_arn
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.generate_questions.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# CORS Configuration
resource "aws_api_gateway_method" "options_questions" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.gemini.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.gemini.id
  http_method = aws_api_gateway_method.options_questions.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "options_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.gemini.id
  http_method = aws_api_gateway_method.options_questions.http_method
  status_code = "200"

  response_headers = {
    "Access-Control-Allow-Headers" = true
    "Access-Control-Allow-Methods" = true
    "Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.gemini.id
  http_method = aws_api_gateway_method.options_questions.http_method
  status_code = aws_api_gateway_method_response.options_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# API Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "v1"

  depends_on = [
    aws_api_gateway_method.post_questions,
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_method.options_questions,
    aws_api_gateway_integration.options_integration,
  ]
}

# Basic CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.generate_questions.function_name}"
  retention_in_days = 7  # Keep logs for 7 days only for V1

  tags = {
    Environment = "v1"
  }
}