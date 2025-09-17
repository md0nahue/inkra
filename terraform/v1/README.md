# Inkra V1 Infrastructure

This directory contains the simplified Terraform infrastructure for Inkra V1 - a minimal viable product without authentication, user management, or complex infrastructure.

## Architecture

```
iOS App (No Auth)
    ├── Native TTS/STT
    ├── Core Data Storage
    └── API Calls → API Gateway → Lambda → Gemini
```

## What's Included

- **Single Lambda Function**: Generates interview questions using Gemini API
- **API Gateway**: Simple REST API with CORS enabled
- **CloudWatch Logs**: Basic logging for Lambda function
- **No Authentication**: Anonymous access for V1 simplicity

## What's NOT Included (V1 Scope)

- ❌ User accounts or authentication
- ❌ Rate limiting or usage tracking
- ❌ Subscription management
- ❌ Cloud sync or user profiles
- ❌ Complex monitoring or alerts

## Prerequisites

1. **AWS CLI** configured with appropriate permissions
2. **Terraform** >= 1.0
3. **Node.js** and **npm** for Lambda packaging
4. **Gemini API Key** from Google AI Studio

## Quick Start

1. **Copy and configure variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your Gemini API key
   ```

2. **Deploy everything:**
   ```bash
   ./deploy.sh
   ```

3. **Test the API:**
   ```bash
   curl -X POST https://your-api-id.execute-api.us-east-1.amazonaws.com/dev/questions/generate \
     -H 'Content-Type: application/json' \
     -d '{"position": "Software Engineer", "company": "Example Corp"}'
   ```

## Manual Deployment

If you prefer manual steps:

```bash
# 1. Build Lambda package
cd lambda
npm install --production
zip -r ../generate_questions.zip .
cd ..

# 2. Deploy with Terraform
terraform init
terraform plan
terraform apply
```

## Configuration

### Required Variables

- `gemini_api_key`: Your Google Gemini API key
- `aws_region`: AWS region (default: us-east-1)
- `project_name`: Project name (default: inkra)
- `environment`: Environment name (default: dev)

### Lambda Environment Variables

The Lambda function uses:
- `GEMINI_API_KEY`: Automatically set from Terraform variable

## API Endpoints

### POST /questions/generate

Generates interview questions for a given position and company.

**Request:**
```json
{
  "position": "Software Engineer",
  "company": "Example Corp"
}
```

**Response:**
```json
{
  "questions": [
    {
      "id": 1,
      "question": "Tell me about your experience with Software Engineer roles at Example Corp.",
      "type": "behavioral",
      "category": "General",
      "difficulty": "medium"
    }
  ],
  "metadata": {
    "position": "Software Engineer",
    "company": "Example Corp",
    "generatedAt": "2024-01-01T00:00:00.000Z"
  }
}
```

## Costs

Expected AWS costs for V1 (minimal usage):
- **Lambda**: ~$0.01/month (includes 1M free requests)
- **API Gateway**: ~$1.00/month (after 1M free requests)
- **CloudWatch Logs**: ~$0.50/month

**Total: ~$1.50/month** for light usage.

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Monitoring

- **CloudWatch Logs**: `/aws/lambda/inkra-generate-questions-dev`
- **Lambda Metrics**: Available in AWS Console
- **API Gateway Metrics**: Available in AWS Console

## Security

V1 is intentionally simple with no authentication. For production use, consider:
- API rate limiting
- Request validation
- Authentication/authorization
- Error handling improvements
- Input sanitization

## Troubleshooting

### Common Issues

1. **"Invalid Gemini API Key"**
   - Verify your API key in terraform.tfvars
   - Check Google AI Studio for key status

2. **"Lambda deployment package too large"**
   - Ensure you're using `npm install --production`
   - Check for unnecessary files in the zip

3. **"CORS errors in browser"**
   - CORS is configured for `*` origin
   - Ensure preflight OPTIONS requests are working

### Logs

Check Lambda logs:
```bash
aws logs tail /aws/lambda/inkra-generate-questions-dev --follow
```

## Next Steps

For V2 features, see the main project roadmap:
- User authentication
- Rate limiting
- Usage analytics
- Enhanced error handling
- Multiple question types