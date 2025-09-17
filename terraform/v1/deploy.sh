#!/bin/bash

# Inkra V1 Simple Deployment Script
# This script deploys the minimal infrastructure for Inkra V1

set -e

echo "🚀 Starting Inkra V1 deployment..."

# Check if required tools are installed
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform is required but not installed. Aborting." >&2; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "❌ npm is required but not installed. Aborting." >&2; exit 1; }
command -v zip >/dev/null 2>&1 || { echo "❌ zip is required but not installed. Aborting." >&2; exit 1; }

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ terraform.tfvars not found. Please copy terraform.tfvars.example and fill in your values."
    exit 1
fi

# Validate required variables
if ! grep -q "gemini_api_key.*=" terraform.tfvars || grep -q "your-gemini-api-key-here" terraform.tfvars; then
    echo "❌ Please set your Gemini API key in terraform.tfvars"
    exit 1
fi

echo "📦 Building Lambda function..."

# Navigate to lambda directory
cd lambda

# Install dependencies
echo "📥 Installing dependencies..."
npm install --production

# Create deployment package
echo "📦 Creating deployment package..."
zip -r ../generate_questions.zip . -x "*.git*" "node_modules/.cache/*"

# Return to terraform directory
cd ..

echo "🏗️ Initializing Terraform..."
terraform init

echo "📋 Planning deployment..."
terraform plan

echo "🚀 Applying deployment..."
terraform apply -auto-approve

echo "✅ Deployment complete!"

# Output the API Gateway URL
API_URL=$(terraform output -raw api_gateway_url)
echo ""
echo "🌐 API Gateway URL: $API_URL"
echo "📋 Test endpoint: $API_URL/questions/generate"
echo ""
echo "📝 To test the endpoint:"
echo "curl -X POST $API_URL/questions/generate \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"position\": \"Software Engineer\", \"company\": \"Example Corp\"}'"
echo ""
echo "🎉 Inkra V1 is ready to use!"