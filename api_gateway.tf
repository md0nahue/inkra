# API Gateway REST API
resource "aws_api_gateway_rest_api" "inkra_api" {
  name        = "${local.project_name}-api-${local.environment}"
  description = "REST API for Inkra interview app"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

# Cognito Authorizer for API Gateway
resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name            = "${local.project_name}-cognito-authorizer-${local.environment}"
  rest_api_id     = aws_api_gateway_rest_api.inkra_api.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.inkra_user_pool.arn]
  identity_source = "method.request.header.Authorization"
}

# API Gateway Resources
resource "aws_api_gateway_resource" "questions" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  parent_id   = aws_api_gateway_rest_api.inkra_api.root_resource_id
  path_part   = "questions"
}

resource "aws_api_gateway_resource" "questions_generate" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  parent_id   = aws_api_gateway_resource.questions.id
  path_part   = "generate"
}

resource "aws_api_gateway_resource" "user" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  parent_id   = aws_api_gateway_rest_api.inkra_api.root_resource_id
  path_part   = "user"
}

resource "aws_api_gateway_resource" "user_profile" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  parent_id   = aws_api_gateway_resource.user.id
  path_part   = "profile"
}

resource "aws_api_gateway_resource" "user_preferences" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  parent_id   = aws_api_gateway_resource.user.id
  path_part   = "preferences"
}

# API Gateway Methods
# POST /questions/generate
resource "aws_api_gateway_method" "questions_generate_post" {
  rest_api_id   = aws_api_gateway_rest_api.inkra_api.id
  resource_id   = aws_api_gateway_resource.questions_generate.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id

  request_validator_id = aws_api_gateway_request_validator.request_validator.id
}

# GET /user/profile
resource "aws_api_gateway_method" "user_profile_get" {
  rest_api_id   = aws_api_gateway_rest_api.inkra_api.id
  resource_id   = aws_api_gateway_resource.user_profile.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

# PUT /user/preferences
resource "aws_api_gateway_method" "user_preferences_put" {
  rest_api_id   = aws_api_gateway_rest_api.inkra_api.id
  resource_id   = aws_api_gateway_resource.user_preferences.id
  http_method   = "PUT"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id

  request_validator_id = aws_api_gateway_request_validator.request_validator.id
}

# OPTIONS methods for CORS
resource "aws_api_gateway_method" "questions_generate_options" {
  rest_api_id   = aws_api_gateway_rest_api.inkra_api.id
  resource_id   = aws_api_gateway_resource.questions_generate.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "user_profile_options" {
  rest_api_id   = aws_api_gateway_rest_api.inkra_api.id
  resource_id   = aws_api_gateway_resource.user_profile.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "user_preferences_options" {
  rest_api_id   = aws_api_gateway_rest_api.inkra_api.id
  resource_id   = aws_api_gateway_resource.user_preferences.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Request Validator
resource "aws_api_gateway_request_validator" "request_validator" {
  name                        = "${local.project_name}-request-validator-${local.environment}"
  rest_api_id                 = aws_api_gateway_rest_api.inkra_api.id
  validate_request_body       = true
  validate_request_parameters = true
}

# Lambda Integrations
resource "aws_api_gateway_integration" "generate_questions_integration" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  resource_id = aws_api_gateway_resource.questions_generate.id
  http_method = aws_api_gateway_method.questions_generate_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.generate_questions.invoke_arn
}

resource "aws_api_gateway_integration" "get_user_profile_integration" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  resource_id = aws_api_gateway_resource.user_profile.id
  http_method = aws_api_gateway_method.user_profile_get.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.get_user_profile.invoke_arn
}

resource "aws_api_gateway_integration" "update_user_preferences_integration" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  resource_id = aws_api_gateway_resource.user_preferences.id
  http_method = aws_api_gateway_method.user_preferences_put.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.update_user_preferences.invoke_arn
}

# CORS Integrations
resource "aws_api_gateway_integration" "questions_generate_cors" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  resource_id = aws_api_gateway_resource.questions_generate.id
  http_method = aws_api_gateway_method.questions_generate_options.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration" "user_profile_cors" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  resource_id = aws_api_gateway_resource.user_profile.id
  http_method = aws_api_gateway_method.user_profile_options.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration" "user_preferences_cors" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  resource_id = aws_api_gateway_resource.user_preferences.id
  http_method = aws_api_gateway_method.user_preferences_options.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Method Responses
resource "aws_api_gateway_method_response" "questions_generate_200" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  resource_id = aws_api_gateway_resource.questions_generate.id
  http_method = aws_api_gateway_method.questions_generate_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "user_profile_200" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  resource_id = aws_api_gateway_resource.user_profile.id
  http_method = aws_api_gateway_method.user_profile_get.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "user_preferences_200" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  resource_id = aws_api_gateway_resource.user_preferences.id
  http_method = aws_api_gateway_method.user_preferences_put.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# CORS Method Responses
resource "aws_api_gateway_method_response" "questions_generate_cors_200" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  resource_id = aws_api_gateway_resource.questions_generate.id
  http_method = aws_api_gateway_method.questions_generate_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_method_response" "user_profile_cors_200" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  resource_id = aws_api_gateway_resource.user_profile.id
  http_method = aws_api_gateway_method.user_profile_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_method_response" "user_preferences_cors_200" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  resource_id = aws_api_gateway_resource.user_preferences.id
  http_method = aws_api_gateway_method.user_preferences_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Integration Responses
resource "aws_api_gateway_integration_response" "questions_generate_cors_response" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  resource_id = aws_api_gateway_resource.questions_generate.id
  http_method = aws_api_gateway_method.questions_generate_options.http_method
  status_code = aws_api_gateway_method_response.questions_generate_cors_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_integration_response" "user_profile_cors_response" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  resource_id = aws_api_gateway_resource.user_profile.id
  http_method = aws_api_gateway_method.user_profile_options.http_method
  status_code = aws_api_gateway_method_response.user_profile_cors_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_integration_response" "user_preferences_cors_response" {
  rest_api_id = aws_api_gateway_rest_api.inkra_api.id
  resource_id = aws_api_gateway_resource.user_preferences.id
  http_method = aws_api_gateway_method.user_preferences_options.http_method
  status_code = aws_api_gateway_method_response.user_preferences_cors_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Lambda Permissions
resource "aws_lambda_permission" "api_gateway_invoke_generate_questions" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.generate_questions.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.inkra_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_invoke_get_user_profile" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_user_profile.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.inkra_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_invoke_update_user_preferences" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_user_preferences.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.inkra_api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "inkra_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.generate_questions_integration,
    aws_api_gateway_integration.get_user_profile_integration,
    aws_api_gateway_integration.update_user_preferences_integration,
    aws_api_gateway_integration.questions_generate_cors,
    aws_api_gateway_integration.user_profile_cors,
    aws_api_gateway_integration.user_preferences_cors
  ]

  rest_api_id = aws_api_gateway_rest_api.inkra_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.questions_generate.id,
      aws_api_gateway_method.questions_generate_post.id,
      aws_api_gateway_integration.generate_questions_integration.id,
      aws_api_gateway_resource.user_profile.id,
      aws_api_gateway_method.user_profile_get.id,
      aws_api_gateway_integration.get_user_profile_integration.id,
      aws_api_gateway_resource.user_preferences.id,
      aws_api_gateway_method.user_preferences_put.id,
      aws_api_gateway_integration.update_user_preferences_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "inkra_api_stage" {
  deployment_id = aws_api_gateway_deployment.inkra_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.inkra_api.id
  stage_name    = local.environment

  # Throttling settings
  # Logging
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip            = "$context.identity.sourceIp"
      caller        = "$context.identity.caller"
      user          = "$context.identity.user"
      requestTime   = "$context.requestTime"
      httpMethod    = "$context.httpMethod"
      resourcePath  = "$context.resourcePath"
      status        = "$context.status"
      error         = "$context.error.message"
      responseLength = "$context.responseLength"
    })
  }

  # Method settings
  tags = local.common_tags
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/api-gateway/${local.project_name}-${local.environment}"
  retention_in_days = 14
  tags              = local.common_tags
}

# Usage Plan
resource "aws_api_gateway_usage_plan" "inkra_usage_plan" {
  name = "${local.project_name}-usage-plan-${local.environment}"

  api_stages {
    api_id = aws_api_gateway_rest_api.inkra_api.id
    stage  = aws_api_gateway_stage.inkra_api_stage.stage_name
  }

  quota_settings {
    limit  = 10000
    period = "MONTH"
  }

  throttle_settings {
    rate_limit  = var.api_throttle_rate_limit
    burst_limit = var.api_throttle_burst_limit
  }

  tags = local.common_tags
}