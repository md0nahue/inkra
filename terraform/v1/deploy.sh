#!/bin/bash

# V1 Deployment Script - Simple deployment without auth

set -e

echo "🚀 Deploying Inkra V1 Infrastructure (No Auth)"

# Check for required tools
command -v terraform >/dev/null 2>&1 || { echo "❌ terraform is required but not installed." >&2; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "❌ npm is required but not installed." >&2; exit 1; }

# Check for Gemini API key
if [ -z "$GEMINI_API_KEY" ]; then
    echo "❌ GEMINI_API_KEY environment variable is not set"
    echo "Get your API key from: https://makersuite.google.com/app/apikey"
    exit 1
fi

# Package Lambda function
echo "📦 Packaging Lambda function..."
cd ../../lambda-functions

# Create package.json if it doesn't exist
if [ ! -f package.json ]; then
    echo "Creating package.json..."
    cat > package.json <<EOF
{
  "name": "inkra-lambda-v1",
  "version": "1.0.0",
  "description": "Simple Lambda for Inkra V1",
  "main": "generateQuestions-v1.js",
  "dependencies": {
    "@google/generative-ai": "^0.21.0"
  }
}
EOF
fi

# Install dependencies
npm install --production

# Create deployment package
echo "Creating deployment package..."
zip -r deployment.zip generateQuestions-v1.js node_modules package.json

# Return to terraform directory
cd ../terraform/v1

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Create terraform.tfvars if it doesn't exist
if [ ! -f terraform.tfvars ]; then
    echo "Creating terraform.tfvars..."
    cat > terraform.tfvars <<EOF
aws_region     = "us-east-1"
project_name   = "inkra"
gemini_api_key = "$GEMINI_API_KEY"
EOF
fi

# Plan deployment
echo "📋 Planning deployment..."
terraform plan

# Ask for confirmation
read -p "Do you want to apply these changes? (yes/no): " -n 3 -r
echo
if [[ $REPLY =~ ^yes$ ]]; then
    # Apply changes
    echo "🏗️ Applying infrastructure changes..."
    terraform apply -auto-approve

    echo "✅ Deployment complete!"
    echo
    echo "📱 iOS App Configuration:"
    terraform output ios_config
else
    echo "❌ Deployment cancelled"
    exit 1
fi