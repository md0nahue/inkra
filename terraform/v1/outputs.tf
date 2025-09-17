# V1 Outputs - Just the essentials

output "api_endpoint" {
  description = "API Gateway endpoint URL for Gemini handler"
  value       = "${aws_api_gateway_deployment.api_deployment.invoke_url}/gemini"
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.generate_questions.function_name
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

# Simple output for iOS app configuration
output "ios_config" {
  description = "Configuration values for iOS app"
  value = {
    api_base_url = aws_api_gateway_deployment.api_deployment.invoke_url
    api_endpoint = "${aws_api_gateway_deployment.api_deployment.invoke_url}/gemini"
    region       = var.aws_region
  }
}