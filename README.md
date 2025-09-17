# Terraform Infrastructure

## Directory Structure

```
terraform/
├── v1/                 # Barebones MVP (NO AUTH)
│   ├── main.tf        # Simple Lambda + API Gateway
│   ├── variables.tf   # Minimal variables
│   └── outputs.tf     # API endpoint
│
├── v2/                 # Full production with auth
│   ├── main.tf        # Complete infrastructure
│   ├── cognito.tf     # User management
│   ├── monitoring.tf  # CloudWatch, alarms
│   └── ...
│
└── modules/            # Reusable components
    ├── lambda/
    ├── api_gateway/
    └── monitoring/
```

## V1 - Barebones (Current Focus)

### What's Included
- Single Lambda function for Gemini API calls
- Public API Gateway (no auth)
- Basic CloudWatch logs
- Minimal IAM roles

### Deployment
```bash
cd terraform/v1
terraform init
terraform plan
terraform apply
```

### Environment Variables
```
GEMINI_API_KEY=your-api-key-here
AWS_REGION=us-east-1
```

## V2 - Full Production (Future)

### Additional Features
- Cognito user pools
- DynamoDB for usage tracking
- S3 for audio storage
- CloudWatch dashboards
- Rate limiting
- API keys
- Subscription tiers

### Not Started Yet
V2 infrastructure will be built after V1 is proven and stable.

## Current State (2025-09-16)

### ⚠️ Legacy Files (to be migrated)
The following files in the root directory need to be organized:
- `api_gateway.tf` - Has auth complexity, needs simplification for V1
- `cognito.tf` - Move to V2, not needed for V1
- `dynamodb.tf` - Move to V2, not needed for V1
- `lambda.tf` - Simplify for V1
- `monitoring.tf` - Reduce for V1, full version for V2

### Migration Plan
1. Copy simplified versions to `v1/`
2. Move full versions to `v2/`
3. Extract common patterns to `modules/`
4. Delete root-level `.tf` files

## Cost Estimates

### V1 Costs (Monthly)
- Lambda: ~$5 (assuming 10K invocations)
- API Gateway: ~$3.50 (REST API)
- CloudWatch: ~$5
- **Total: ~$15/month**

### V2 Costs (Monthly)
- All V1 costs
- Cognito: ~$50 (1000 MAU)
- DynamoDB: ~$25
- S3: ~$10
- Enhanced monitoring: ~$20
- **Total: ~$120/month**

## Terraform Version
Required: >= 1.0
Recommended: 1.5.x

## Provider Versions
- AWS Provider: ~> 5.0
- Random Provider: ~> 3.0