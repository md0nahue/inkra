# Cognito Outputs
output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.inkra_user_pool.id
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.inkra_user_pool.arn
}

output "cognito_user_pool_endpoint" {
  description = "Endpoint of the Cognito User Pool"
  value       = aws_cognito_user_pool.inkra_user_pool.endpoint
}

output "cognito_user_pool_client_id" {
  description = "ID of the Cognito User Pool Client for iOS"
  value       = aws_cognito_user_pool_client.inkra_ios_client.id
}

output "cognito_identity_pool_id" {
  description = "ID of the Cognito Identity Pool"
  value       = aws_cognito_identity_pool.inkra_identity_pool.id
}

output "cognito_hosted_ui_domain" {
  description = "Cognito Hosted UI domain"
  value       = "https://${aws_cognito_user_pool_domain.inkra_domain.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
}

# API Gateway Outputs
output "api_gateway_url" {
  description = "Base URL of the API Gateway"
  value       = "https://${aws_api_gateway_rest_api.inkra_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${local.environment}"
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.inkra_api.id
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.inkra_api.execution_arn
}

# API Endpoints
output "generate_questions_endpoint" {
  description = "Endpoint for generating interview questions"
  value       = "https://${aws_api_gateway_rest_api.inkra_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${local.environment}/questions/generate"
}

output "get_user_profile_endpoint" {
  description = "Endpoint for getting user profile"
  value       = "https://${aws_api_gateway_rest_api.inkra_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${local.environment}/user/profile"
}

output "update_user_preferences_endpoint" {
  description = "Endpoint for updating user preferences"
  value       = "https://${aws_api_gateway_rest_api.inkra_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${local.environment}/user/preferences"
}

# Lambda Function Outputs
output "generate_questions_lambda_function_name" {
  description = "Name of the Generate Questions Lambda function"
  value       = aws_lambda_function.generate_questions.function_name
}

output "get_user_profile_lambda_function_name" {
  description = "Name of the Get User Profile Lambda function"
  value       = aws_lambda_function.get_user_profile.function_name
}

output "update_user_preferences_lambda_function_name" {
  description = "Name of the Update User Preferences Lambda function"
  value       = aws_lambda_function.update_user_preferences.function_name
}

# DynamoDB Outputs
output "usage_table_name" {
  description = "Name of the usage tracking DynamoDB table"
  value       = aws_dynamodb_table.inkra_usage.name
}

output "usage_table_arn" {
  description = "ARN of the usage tracking DynamoDB table"
  value       = aws_dynamodb_table.inkra_usage.arn
}

output "sessions_table_name" {
  description = "Name of the sessions DynamoDB table"
  value       = aws_dynamodb_table.inkra_sessions.name
}

output "sessions_table_arn" {
  description = "ARN of the sessions DynamoDB table"
  value       = aws_dynamodb_table.inkra_sessions.arn
}

# Monitoring Outputs
output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch Dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.inkra_dashboard.dashboard_name}"
}

output "sns_alerts_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.inkra_alerts.arn
}

# iOS Configuration
output "ios_sdk_configuration" {
  description = "Configuration object for iOS SDK"
  value = {
    region                = data.aws_region.current.name
    userPoolId           = aws_cognito_user_pool.inkra_user_pool.id
    userPoolClientId     = aws_cognito_user_pool_client.inkra_ios_client.id
    identityPoolId       = aws_cognito_identity_pool.inkra_identity_pool.id
    apiGatewayUrl        = "https://${aws_api_gateway_rest_api.inkra_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${local.environment}"
    hostedUIDomain       = "${aws_cognito_user_pool_domain.inkra_domain.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
    redirectScheme       = var.ios_bundle_id
  }
}

# Rate Limiting Configuration
output "rate_limiting_config" {
  description = "Rate limiting configuration for the app"
  value = {
    freeTierDailyLimit    = var.free_tier_daily_limit
    premiumTierDailyLimit = var.premium_tier_daily_limit
    apiThrottleRateLimit  = var.api_throttle_rate_limit
    apiThrottleBurstLimit = var.api_throttle_burst_limit
  }
}

# Environment Information
output "environment" {
  description = "Deployment environment"
  value       = local.environment
}

output "project_name" {
  description = "Project name"
  value       = local.project_name
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}

# Important Notes for Deployment
output "deployment_notes" {
  description = "Important notes for deployment and usage"
  value = {
    next_steps = [
      "1. Set the gemini_api_key variable with your Google Gemini API key",
      "2. Run 'terraform init' to initialize the Terraform configuration",
      "3. Run 'terraform plan' to review the deployment plan",
      "4. Run 'terraform apply' to deploy the infrastructure",
      "5. Configure SNS topic subscriptions for alerts if needed",
      "6. Update iOS app with the provided configuration values",
      "7. Test the API endpoints with proper Cognito authentication"
    ]

    security_considerations = [
      "Gemini API key is stored as a sensitive variable - use secure methods to provide it",
      "All Lambda functions have least-privilege IAM policies",
      "API Gateway uses Cognito User Pool for authentication",
      "DynamoDB tables have encryption at rest enabled",
      "CloudWatch logs are retained for 14 days"
    ]

    cost_optimization = [
      "DynamoDB tables use on-demand billing",
      "Lambda functions are optimized for memory and timeout",
      "CloudWatch logs have reasonable retention periods",
      "Budget alert is set for monthly cost monitoring"
    ]
  }
}