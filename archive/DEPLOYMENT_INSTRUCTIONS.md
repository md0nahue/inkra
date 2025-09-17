# Inkra Deployment Instructions

This guide walks through deploying the Inkra AWS infrastructure and integrating it with the iOS app.

## Prerequisites

1. **AWS CLI** configured with appropriate permissions
2. **Terraform** v1.0+ installed
3. **Node.js** 18+ for Lambda functions
4. **Xcode** 15+ for iOS development
5. **Google Gemini API Key** from [Google AI Studio](https://aistudio.google.com/app/apikey)

## Step 1: Configure Variables

1. Copy the example configuration:
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` and replace:
   - `gemini_api_key` with your actual Google Gemini API key
   - `ios_bundle_id` with your iOS app bundle identifier
   - Adjust other settings as needed

## Step 2: Install Lambda Dependencies

```bash
cd lambda-functions
npm install
cd ..
```

## Step 3: Deploy AWS Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the infrastructure
terraform apply
```

Save the outputs from `terraform apply` - you'll need them for iOS configuration.

## Step 4: Configure iOS App

After successful deployment, configure your iOS app with the AWS resources:

1. **Get Terraform Outputs**:
```bash
terraform output -json > aws-config.json
```

2. **Add AWS SDK to iOS Project**:
Add the following to your Package.swift or through Xcode Package Manager:
```
https://github.com/aws-amplify/aws-sdk-ios-spm
```

3. **Configure AWS in iOS**:
Update your app with the Terraform outputs:

```swift
// In your app initialization
let cognitoService = CognitoAuthService.shared
cognitoService.configure(
    userPoolId: "OUTPUT_USER_POOL_ID",
    clientId: "OUTPUT_USER_POOL_CLIENT_ID",
    region: "us-east-1"
)

let lambdaService = LambdaService.shared
lambdaService.configure(
    apiGatewayURL: "OUTPUT_API_GATEWAY_URL"
)
```

## Step 5: Test the Integration

1. **Test Lambda Functions**:
```bash
# Test question generation
curl -X POST "YOUR_API_GATEWAY_URL/questions/generate" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "position": "Software Engineer",
    "company": "Test Company",
    "difficulty": "medium",
    "questionType": "behavioral"
  }'
```

2. **Test iOS Authentication**:
   - Sign up a new user
   - Verify email
   - Sign in
   - Generate questions

## Step 6: Monitor and Debug

1. **View Lambda Logs**:
```bash
aws logs tail /aws/lambda/inkra-generate-questions-dev --follow
```

2. **Monitor DynamoDB**:
```bash
aws dynamodb scan --table-name inkra-usage-dev
```

3. **Check CloudWatch Dashboards**:
Visit AWS Console → CloudWatch → Dashboards → inkra-dashboard-dev

## Troubleshooting

### Common Issues

1. **Lambda Function Timeout**:
   - Check CloudWatch logs for specific errors
   - Verify Gemini API key is correct
   - Ensure network connectivity

2. **Authentication Errors**:
   - Verify Cognito User Pool configuration
   - Check JWT token format
   - Ensure iOS app has correct pool ID and client ID

3. **Rate Limiting Issues**:
   - Check DynamoDB usage table
   - Verify user subscription tier
   - Monitor API Gateway throttling

4. **iOS Build Errors**:
   - Ensure all Swift files are added to Xcode project
   - Verify AWS SDK dependencies are properly linked
   - Check for missing @MainActor annotations

### Validation Steps

✅ AWS infrastructure deployed successfully
✅ Lambda functions respond to test requests
✅ Cognito user pool accepts new registrations
✅ DynamoDB tables are created and accessible
✅ iOS app builds without errors
✅ iOS app can authenticate users
✅ iOS app can generate questions via Lambda
✅ Rate limiting works correctly
✅ Audio recording and playback functions
✅ Speech-to-text recognition works
✅ Text-to-speech synthesis works

## Performance Optimization

1. **Lambda Cold Starts**:
   - Consider provisioned concurrency for production
   - Optimize package size
   - Use ARM-based Lambda functions

2. **DynamoDB Optimization**:
   - Monitor read/write capacity
   - Use on-demand billing for variable workloads
   - Implement proper TTL for old usage records

3. **iOS Performance**:
   - Cache AWS configuration locally
   - Implement request queuing for offline scenarios
   - Use background tasks for non-critical operations

## Security Checklist

✅ Gemini API key stored securely (not in code)
✅ AWS IAM permissions follow least privilege
✅ Cognito user pool configured with secure policies
✅ API Gateway has proper CORS configuration
✅ Lambda functions validate all inputs
✅ DynamoDB tables have encryption at rest
✅ iOS app validates all server responses
✅ Authentication tokens have appropriate expiration

## Next Steps

1. **Testing**: Implement comprehensive unit and integration tests
2. **Monitoring**: Set up alerts for errors and performance issues
3. **Scaling**: Configure auto-scaling for production loads
4. **CI/CD**: Implement automated deployment pipeline
5. **Backup**: Configure DynamoDB backups
6. **Documentation**: Create user guides and API documentation

## Support

For issues:
1. Check CloudWatch logs for detailed error information
2. Review AWS service quotas and limits
3. Consult AWS documentation for service-specific issues
4. Use AWS Support if you have a support plan

---

**Note**: This deployment sets up a development environment. For production:
- Use separate Terraform workspaces
- Implement proper secrets management
- Configure monitoring and alerting
- Set up backup and disaster recovery
- Review security and compliance requirements