# 🚀 Inkra AWS Deployment Guide

Complete guide to deploy the Inkra serverless backend infrastructure.

## 📋 Prerequisites

### Required Tools
- **AWS CLI** (latest version)
- **Terraform** >= 1.0
- **Node.js** >= 18
- **jq** (for JSON parsing)

### AWS Account Setup
1. AWS account with billing enabled
2. IAM user with appropriate permissions:
   - Lambda (full access)
   - API Gateway (full access)
   - Cognito (full access)
   - DynamoDB (full access)
   - CloudWatch (full access)
   - IAM (limited - for role creation)

### API Keys
- **Gemini API Key**: Get from https://aistudio.google.com/app/apikey

---

## 🛠 Quick Start Deployment

### 1. Clone and Setup

```bash
cd /path/to/inkra
```

### 2. Configure AWS Credentials

```bash
# Option A: AWS CLI configure
aws configure

# Option B: Environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### 3. Setup Terraform Variables

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Required changes in `terraform.tfvars`:**
```hcl
# REQUIRED: Your Gemini API key
gemini_api_key = "your-actual-gemini-api-key-here"

# Optional: Customize these
environment = "dev"
aws_region = "us-east-1"
ios_bundle_id = "com.yourcompany.inkra"
budget_alert_email = "you@yourcompany.com"
```

### 4. Deploy Infrastructure

```bash
# Make script executable and run
chmod +x deploy.sh
./deploy.sh
```

**That's it!** The script will:
- Install Lambda dependencies
- Initialize Terraform
- Create deployment plan
- Apply infrastructure
- Validate deployment
- Show configuration values

---

## 📱 Manual Deployment Steps

If you prefer manual control:

### 1. Install Lambda Dependencies

```bash
cd lambda-functions
npm install --production
cd ..
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan Deployment

```bash
terraform plan -var-file="terraform.tfvars" -out=tfplan
```

### 4. Apply Infrastructure

```bash
terraform apply tfplan
```

### 5. Get Configuration Values

```bash
# All outputs
terraform output

# Specific values for iOS
terraform output ios_sdk_configuration
terraform output api_gateway_url
```

---

## 🧪 Testing the Deployment

### 1. Test Lambda Functions

```bash
# Test generate questions function
aws lambda invoke \
  --function-name $(terraform output -raw lambda_function_names | jq -r '.generate_questions') \
  --payload '{"body": "{\"position\":\"iOS Developer\",\"company\":\"TestCorp\"}"}' \
  --region us-east-1 \
  response.json

cat response.json
```

### 2. Test API Gateway

```bash
# Get API URL
API_URL=$(terraform output -raw api_gateway_url)

# Test CORS preflight
curl -X OPTIONS "$API_URL/questions/generate" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type,Authorization"

# Test authenticated endpoint (requires Cognito token)
curl -X POST "$API_URL/questions/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_COGNITO_JWT_TOKEN" \
  -d '{"position":"iOS Developer","company":"Apple"}'
```

### 3. Monitor CloudWatch

Visit the dashboard:
```bash
terraform output cloudwatch_dashboard_url
```

---

## 📊 What Gets Deployed

### AWS Resources Created:

#### 🔐 **Authentication & Authorization**
- **Cognito User Pool**: User registration and authentication
- **Cognito Identity Pool**: AWS SDK access for mobile apps
- **User Groups**: Free tier and premium tier management

#### 🗄 **Data Storage**
- **DynamoDB Table**: Usage tracking and rate limiting
  - On-demand billing
  - TTL enabled (90-day cleanup)
  - Global Secondary Index for date queries

#### ⚡ **Compute & API**
- **3 Lambda Functions**:
  - `generateQuestions`: Gemini AI integration with rate limiting
  - `getUserProfile`: User data and usage statistics
  - `updateUserPreferences`: Settings management
- **API Gateway**: REST API with CORS and throttling
- **Lambda Layers**: Shared dependencies (if needed)

#### 📈 **Monitoring & Alerts**
- **CloudWatch Logs**: Function execution logs (14-day retention)
- **CloudWatch Dashboard**: Real-time metrics
- **CloudWatch Alarms**: Error and latency monitoring
- **SNS Topic**: Alert notifications
- **Cost Budget**: Monthly spending alerts ($50 threshold)

#### 🔒 **Security**
- **IAM Roles**: Least-privilege access for Lambda functions
- **API Gateway Authorizer**: Cognito-based authentication
- **Request Validation**: Input validation on API endpoints

---

## 💰 Cost Estimation

### Monthly Costs (Development Environment):

| Service | Usage | Cost |
|---------|-------|------|
| **Lambda** | 10k invocations, 512MB, 30s avg | ~$2.50 |
| **API Gateway** | 10k requests | ~$0.04 |
| **DynamoDB** | On-demand, light usage | ~$1.00 |
| **Cognito** | 1k active users | ~$0.55 |
| **CloudWatch** | Standard monitoring | ~$1.00 |
| **Data Transfer** | Light usage | ~$0.50 |
| **Total** | | **~$5.59/month** |

### Production Scale (100k users):
- **Lambda**: ~$25/month
- **API Gateway**: ~$4/month
- **DynamoDB**: ~$10/month
- **Cognito**: ~$55/month
- **Total**: **~$100/month**

---

## 🔧 Advanced Configuration

### Environment-Specific Deployments

Deploy to different environments:

```bash
# Development
./deploy.sh -e dev -r us-east-1

# Staging
./deploy.sh -e staging -r us-west-2

# Production
./deploy.sh -e prod -r us-east-1
```

### Custom Variable Overrides

Create environment-specific variable files:

```bash
# terraform.tfvars.prod
environment = "prod"
free_tier_daily_limit = 5
premium_tier_daily_limit = 200
api_throttle_rate_limit = 50
budget_alert_email = "production-alerts@yourcompany.com"
```

Deploy with custom vars:
```bash
terraform apply -var-file="terraform.tfvars.prod"
```

### Backend State Management

For production, use remote state:

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "inkra/terraform.tfstate"
    region = "us-east-1"

    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

---

## 🔍 Troubleshooting

### Common Issues:

#### 1. **Terraform Init Fails**
```bash
# Clear cache and retry
rm -rf .terraform*
terraform init
```

#### 2. **Lambda Package Too Large**
```bash
# Check lambda-functions directory size
du -sh lambda-functions/

# Remove dev dependencies
cd lambda-functions && npm prune --production
```

#### 3. **API Gateway 403 Errors**
- Verify Cognito token is valid
- Check API Gateway logs in CloudWatch
- Ensure CORS is configured properly

#### 4. **DynamoDB Permission Errors**
- Verify IAM role has DynamoDB permissions
- Check resource ARNs in IAM policy

#### 5. **Lambda Cold Start Issues**
- Consider provisioned concurrency for production
- Optimize Lambda function initialization

### Debug Commands:

```bash
# Check AWS credentials
aws sts get-caller-identity

# Validate Terraform syntax
terraform validate

# Check Lambda function logs
aws logs tail /aws/lambda/inkra-generate-questions-dev --follow

# Test Lambda function directly
aws lambda invoke \
  --function-name inkra-generate-questions-dev \
  --payload file://test-payload.json \
  response.json
```

---

## 🗑 Cleanup

### Destroy Infrastructure

```bash
# Interactive destruction
./deploy.sh -d

# Force destruction (careful!)
terraform destroy -auto-approve -var-file="terraform.tfvars"
```

### Partial Cleanup

```bash
# Remove only Lambda functions
terraform destroy -target=aws_lambda_function.generate_questions

# Remove only API Gateway
terraform destroy -target=aws_api_gateway_rest_api.inkra_api
```

---

## 📝 Next Steps After Deployment

### 1. **iOS App Configuration**

Use the Terraform outputs to configure your iOS app:

```swift
// AWSConfiguration.swift
struct AWSConfiguration {
    static let userPoolId = "us-east-1_XXXXXXXX"        // From output
    static let userPoolClientId = "your-client-id"       // From output
    static let identityPoolId = "us-east-1:guid"         // From output
    static let apiGatewayURL = "https://api-id.execute-api.us-east-1.amazonaws.com/dev"
    static let region = "us-east-1"
}
```

### 2. **Create Test Users**

```bash
# Create a test user in Cognito
aws cognito-idp admin-create-user \
  --user-pool-id $(terraform output -raw cognito_user_pool_id) \
  --username "testuser@example.com" \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS
```

### 3. **Monitor and Scale**

- Set up CloudWatch alarms
- Monitor costs in AWS Billing
- Configure auto-scaling if needed
- Set up CI/CD pipeline for updates

### 4. **Security Hardening**

- Enable AWS CloudTrail for audit logs
- Set up AWS Config for compliance
- Configure AWS WAF for API protection
- Enable AWS GuardDuty for threat detection

---

## 🎯 Production Checklist

Before going live:

- [ ] SSL certificate configured
- [ ] Custom domain name setup
- [ ] Rate limiting tested
- [ ] Error handling verified
- [ ] Monitoring alerts configured
- [ ] Backup strategy in place
- [ ] Security scan completed
- [ ] Load testing performed
- [ ] Documentation updated

---

**🚀 You're now ready to deploy Inkra's serverless backend!**

For support, check the troubleshooting section or review CloudWatch logs.