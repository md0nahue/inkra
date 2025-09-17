# Inkra V1 Prototype Plan
## Get Gemini Question Generation Working

**Goal**: Deploy the existing Lambda function with Gemini API integration and test it from the iOS app.

**Timeline**: 1-2 days maximum

---

## What We Already Have ✅

### Lambda Function (Ready to Deploy)
- `lambda-functions/generateQuestions.js` - Complete implementation with Gemini API
- `lambda.tf` - Terraform configuration for Lambda deployment
- `package.json` - Dependencies including `@google/generative-ai`

### iOS Integration (Ready to Use)
- `LambdaService.swift` - Complete service with `generateQuestions()` method
- `CognitoAuthService.swift` - Authentication handling
- Error handling and retry logic already implemented

### Infrastructure (Ready to Deploy)
- `lambda.tf` - Lambda function with environment variables
- `api_gateway.tf` - API Gateway endpoint configuration
- `cognito.tf` - Authentication setup

---

## V1 Deployment Steps

### Step 1: Configure Environment (10 minutes)
```bash
# 1. Get Gemini API key from https://aistudio.google.com/app/apikey
# 2. Create terraform.tfvars
echo 'gemini_api_key = "your-api-key-here"' > terraform.tfvars
echo 'ios_bundle_id = "com.yourcompany.inkra"' >> terraform.tfvars
```

### Step 2: Deploy Lambda Only (15 minutes)
```bash
# Install dependencies
cd lambda-functions && npm install && cd ..

# Deploy just the Lambda and API Gateway
terraform init
terraform apply -target=aws_lambda_function.generate_questions -target=aws_api_gateway_rest_api.inkra_api
```

### Step 3: Test Endpoint (5 minutes)
```bash
# Get the API Gateway URL from Terraform output
API_URL=$(terraform output -raw api_gateway_url)

# Test the endpoint
curl -X POST "$API_URL/questions/generate" \
  -H "Content-Type: application/json" \
  -d '{
    "position": "Software Engineer",
    "company": "Test Company",
    "difficulty": "medium",
    "questionType": "behavioral"
  }'
```

### Step 4: Configure iOS App (5 minutes)
```swift
// In your app startup
let lambdaService = LambdaService.shared
lambdaService.configure(apiGatewayURL: "YOUR_API_GATEWAY_URL")

// Test question generation
Task {
    do {
        let questions = try await lambdaService.generateQuestions(
            position: "Software Engineer",
            company: "Test Company"
        )
        print("Generated \(questions.questions.count) questions")
    } catch {
        print("Error: \(error)")
    }
}
```

---

## That's It! 🎉

**Total Time**: ~35 minutes
**Result**: Working Gemini question generation from iOS app

---

## What We're NOT Doing (Yet)

❌ **Complex Infrastructure**: No DynamoDB, CloudWatch, monitoring, etc.
❌ **Authentication**: Skip Cognito for V1 (can add later)
❌ **Rate Limiting**: Skip usage tracking for prototype
❌ **Error Handling**: Use basic implementation
❌ **Testing**: Skip comprehensive test suites
❌ **Migration**: No data migration needed
❌ **Rollback**: No complex rollback mechanisms

---

## Key Files for V1

### Essential Files (Must Have)
- `lambda-functions/generateQuestions.js` - The actual Lambda code
- `lambda-functions/package.json` - Dependencies
- `lambda.tf` - Lambda deployment config
- `api_gateway.tf` - API endpoint config
- `LambdaService.swift` - iOS integration

### Optional Files (Nice to Have)
- `cognito.tf` - Authentication (can add later)
- `dynamodb.tf` - Usage tracking (can add later)
- `monitoring.tf` - CloudWatch (can add later)

---

## Success Criteria

✅ Lambda function deploys successfully
✅ API Gateway endpoint is accessible
✅ Gemini API returns valid questions
✅ iOS app can call the endpoint
✅ Questions display in the app

---

## When V1 Works, Then Consider

1. **Add Authentication**: Deploy Cognito and update iOS app
2. **Add Rate Limiting**: Deploy DynamoDB usage tracking
3. **Add Monitoring**: Deploy CloudWatch dashboards
4. **Add Error Handling**: Implement comprehensive error flows
5. **Add Testing**: Create test suites
6. **Plan Production**: Use the archived comprehensive plans

---

## Troubleshooting V1

### Lambda Issues
```bash
# Check Lambda logs
aws logs tail /aws/lambda/inkra-generate-questions-dev --follow
```

### API Gateway Issues
```bash
# Test API Gateway directly
curl -X POST "YOUR_API_URL/questions/generate" -v
```

### Gemini API Issues
- Verify API key is correct
- Check quota limits at https://aistudio.google.com/
- Ensure proper JSON formatting

### iOS Issues
- Check network permissions in Info.plist
- Verify URL is correct
- Use iOS simulator network debugging

---

**Remember**: This is a prototype. Get it working first, optimize later!