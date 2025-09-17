# Infrastructure

This directory contains the infrastructure-as-code configuration for Inkra.

## Terraform

The `terraform/` directory contains Terraform configurations for AWS infrastructure deployment.

### What it does:

**Core Infrastructure:**
- **Lambda Function**: Hosts the AI service for processing interview questions using Google's Gemini API
- **API Gateway**: Provides a REST API endpoint (`/ai`) for the iOS app to communicate with the Lambda function
- **IAM Roles**: Basic execution role for Lambda with CloudWatch logging permissions
- **CloudWatch Logs**: Captures Lambda function logs with 7-day retention

**API Configuration:**
- Single POST endpoint at `/ai` for AI question processing
- CORS enabled for cross-origin requests from iOS app
- No authentication (V1 MVP configuration)
- Regional API Gateway deployment

**Key Features:**
- Simple, barebones setup focused on MVP functionality
- Environment variables for Gemini API key configuration
- Basic error logging and monitoring
- iOS app integration outputs for easy configuration

### Files:

- `main.tf` - Main infrastructure resources (Lambda, API Gateway, IAM)
- `outputs.tf` - Outputs the API endpoint URL and configuration for iOS app integration
- `variables.tf` - Input variables for customization
- `terraform.tfvars.example` - Example variable values
- `deploy.sh` - Deployment script
- `README.md` - Original terraform documentation
- `v2/` - Future version configurations
- `modules/` - Reusable terraform modules

This is a V1 configuration optimized for rapid MVP deployment without authentication or advanced security features.