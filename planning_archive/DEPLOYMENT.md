# Inkra iOS App - AWS Infrastructure

This Terraform configuration provisions the complete AWS infrastructure for the Inkra interview preparation iOS app, including authentication, API endpoints, database storage, rate limiting, and monitoring.

## Architecture Overview

The infrastructure includes:

- **AWS Cognito**: User authentication and authorization with custom attributes for subscription tiers
- **API Gateway**: RESTful API with Cognito authorization and CORS support
- **Lambda Functions**: Serverless backend for question generation, user profiles, and preferences
- **DynamoDB**: NoSQL database for usage tracking and session management
- **CloudWatch**: Comprehensive monitoring, alerting, and dashboards
- **SNS**: Alert notifications for system issues

## Prerequisites

1. **AWS Account**: With appropriate permissions to create the resources
2. **Terraform**: Version >= 1.0 installed
3. **Google Gemini API Key**: Get from [Google AI Studio](https://aistudio.google.com/app/apikey)
4. **AWS CLI**: Configured with your credentials

## Quick Start

1. **Clone and Navigate**
   ```bash
   cd inkra
   ```

2. **Configure Variables**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your actual values
   ```

3. **Initialize and Deploy**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Save Outputs**
   ```bash
   terraform output -json > infrastructure-outputs.json
   ```

## Configuration Variables

### Required Variables

- `gemini_api_key`: Your Google Gemini API key (sensitive)
- `ios_bundle_id`: Your iOS app bundle identifier

### Optional Variables

- `aws_region`: AWS region (default: us-east-1)
- `environment`: Deployment environment (default: dev)
- `free_tier_daily_limit`: Daily questions for free users (default: 10)
- `premium_tier_daily_limit`: Daily questions for premium users (default: 100)
- `api_throttle_rate_limit`: API requests per second (default: 10)
- `api_throttle_burst_limit`: API burst capacity (default: 20)

## API Endpoints

After deployment, you'll have these endpoints:

- `POST /questions/generate`: Generate interview questions
- `GET /user/profile`: Get user profile and usage stats
- `PUT /user/preferences`: Update user preferences

All endpoints require Cognito authentication via Authorization header.

## iOS Integration

Use the `ios_sdk_configuration` output to configure your iOS app:

```swift
// Example configuration in your iOS app
let userPoolId = "us-east-1_XXXXXXXXX"
let userPoolClientId = "XXXXXXXXXXXXXXXXXXXXXXXXXX"
let identityPoolId = "us-east-1:XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
let apiGatewayUrl = "https://XXXXXXXXXX.execute-api.us-east-1.amazonaws.com/dev"
```

## Monitoring and Alerts

### CloudWatch Dashboard
Access your dashboard at: `https://console.aws.amazon.com/cloudwatch/home#dashboards`

### Configured Alerts
- Lambda function errors and timeouts
- API Gateway 4xx/5xx errors and high latency
- DynamoDB throttling
- Monthly cost budget (default: $50)

### SNS Topic
Subscribe to the alerts topic for notifications:
```bash
aws sns subscribe --topic-arn <SNS_TOPIC_ARN> --protocol email --notification-endpoint your-email@example.com
```

## Rate Limiting

The system implements user-based rate limiting:

- **Free Tier**: 10 questions per day
- **Premium Tier**: 100 questions per day
- **Tracking**: Hourly granularity with 90-day TTL
- **Error Handling**: Graceful responses with reset times

## Security Features

- **Authentication**: Cognito User Pools with MFA support
- **Authorization**: JWT tokens validated by API Gateway
- **Encryption**: DynamoDB encryption at rest
- **IAM**: Least-privilege access policies
- **HTTPS**: All API communications encrypted in transit

## Cost Optimization

- **DynamoDB**: On-demand billing scales with usage
- **Lambda**: Pay-per-invocation with optimized memory settings
- **CloudWatch**: 14-day log retention
- **Budget**: Monthly cost monitoring and alerts

## Troubleshooting

### Common Issues

1. **Terraform Init Fails**
   - Ensure AWS credentials are configured
   - Check internet connectivity for provider downloads

2. **Deploy Fails**
   - Verify IAM permissions
   - Check region availability for services
   - Ensure unique S3 bucket names if using remote state

3. **Lambda Functions Timeout**
   - Check CloudWatch logs for detailed errors
   - Verify environment variables are set correctly
   - Ensure Gemini API key is valid

4. **API Authentication Fails**
   - Verify Cognito User Pool configuration
   - Check JWT token format and expiration
   - Ensure CORS is properly configured

### Useful Commands

```bash
# View all outputs
terraform output

# View specific output
terraform output api_gateway_url

# Check Lambda logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/inkra"

# Test API endpoint
curl -X GET https://YOUR-API-GATEWAY-URL/dev/user/profile \
  -H "Authorization: Bearer YOUR-JWT-TOKEN"
```

## Development Workflow

1. **Local Testing**: Use AWS SAM or LocalStack for local development
2. **Staging**: Deploy to staging environment first
3. **Production**: Use separate Terraform workspaces for prod
4. **CI/CD**: Integrate with GitHub Actions or similar

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

⚠️ **Warning**: This will permanently delete all data and resources.

## Support

For issues or questions:
1. Check CloudWatch logs for error details
2. Review AWS service quotas and limits
3. Consult AWS documentation for service-specific issues
4. Use AWS Support if you have a support plan