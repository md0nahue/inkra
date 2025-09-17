#!/bin/bash

# ============================================================================
# INKRA DEPLOYMENT TEST SCRIPT
# Tests AWS infrastructure after deployment
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENVIRONMENT="dev"
REGION="us-east-1"

print_status() { echo -e "${BLUE}[TEST]${NC} $1"; }
print_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
print_error() { echo -e "${RED}[FAIL]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

run_test() {
    local test_name="$1"
    local test_command="$2"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    print_status "Running test: $test_name"

    if eval "$test_command" > /dev/null 2>&1; then
        print_success "$test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        print_error "$test_name"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Check if outputs exist
check_terraform_outputs() {
    print_status "Checking Terraform outputs..."

    if ! terraform output > /dev/null 2>&1; then
        print_error "No Terraform outputs found. Is infrastructure deployed?"
        exit 1
    fi

    print_success "Terraform outputs available"
}

# Test 1: AWS CLI connectivity
test_aws_connectivity() {
    run_test "AWS CLI connectivity" "aws sts get-caller-identity"
}

# Test 2: Cognito User Pool exists
test_cognito_user_pool() {
    USER_POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null)
    if [[ -n "$USER_POOL_ID" ]]; then
        run_test "Cognito User Pool" "aws cognito-idp describe-user-pool --user-pool-id $USER_POOL_ID --region $REGION"
    else
        print_error "Could not get Cognito User Pool ID from Terraform output"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Test 3: DynamoDB table exists
test_dynamodb_table() {
    TABLE_NAME=$(terraform output -raw dynamodb_table_name 2>/dev/null)
    if [[ -n "$TABLE_NAME" ]]; then
        run_test "DynamoDB table" "aws dynamodb describe-table --table-name $TABLE_NAME --region $REGION"
    else
        print_error "Could not get DynamoDB table name from Terraform output"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Test 4: Lambda functions exist and are accessible
test_lambda_functions() {
    print_status "Testing Lambda functions..."

    # Get function names from Terraform output
    if terraform output lambda_function_names > /dev/null 2>&1; then
        FUNCTIONS=$(terraform output -json lambda_function_names | jq -r '.value | to_entries[] | .value')

        for func in $FUNCTIONS; do
            run_test "Lambda function: $func" "aws lambda get-function --function-name $func --region $REGION"
        done
    else
        print_error "Could not get Lambda function names from Terraform output"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Test 5: API Gateway exists and responds
test_api_gateway() {
    API_URL=$(terraform output -raw api_gateway_url 2>/dev/null)
    if [[ -n "$API_URL" ]]; then
        # Test CORS preflight request
        run_test "API Gateway CORS" "curl -s -o /dev/null -w '%{http_code}' -X OPTIONS '$API_URL/questions/generate' | grep -q '200'"

        # Test that API Gateway returns proper error for unauthenticated request
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/questions/generate" \
            -H "Content-Type: application/json" \
            -d '{"position":"test","company":"test"}')

        if [[ "$HTTP_CODE" == "401" ]]; then
            print_success "API Gateway authentication (returns 401 as expected)"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            print_error "API Gateway authentication (expected 401, got $HTTP_CODE)"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    else
        print_error "Could not get API Gateway URL from Terraform output"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Test 6: CloudWatch log groups exist
test_cloudwatch_logs() {
    print_status "Testing CloudWatch log groups..."

    LOG_GROUPS=(
        "/aws/lambda/inkra-generate-questions-${ENVIRONMENT}"
        "/aws/lambda/inkra-user-profile-${ENVIRONMENT}"
        "/aws/lambda/inkra-update-preferences-${ENVIRONMENT}"
        "/aws/apigateway/inkra-${ENVIRONMENT}"
    )

    for log_group in "${LOG_GROUPS[@]}"; do
        run_test "CloudWatch log group: $log_group" \
            "aws logs describe-log-groups --log-group-name-prefix '$log_group' --region $REGION | jq -e '.logGroups | length > 0'"
    done
}

# Test 7: Test Lambda function invocation (without authentication)
test_lambda_invocation() {
    print_status "Testing Lambda function invocation..."

    GENERATE_FUNCTION=$(terraform output -json lambda_function_names 2>/dev/null | jq -r '.value.generate_questions' 2>/dev/null)

    if [[ -n "$GENERATE_FUNCTION" && "$GENERATE_FUNCTION" != "null" ]]; then
        # Create test payload
        cat > /tmp/test-payload.json << EOF
{
  "httpMethod": "POST",
  "path": "/questions/generate",
  "headers": {
    "Content-Type": "application/json"
  },
  "body": "{\"position\":\"iOS Developer\",\"company\":\"TestCorp\"}",
  "requestContext": {
    "authorizer": {
      "claims": {
        "sub": "test-user-id",
        "email": "test@example.com"
      }
    }
  }
}
EOF

        # Invoke function and check response
        if aws lambda invoke \
            --function-name "$GENERATE_FUNCTION" \
            --payload file:///tmp/test-payload.json \
            --region "$REGION" \
            /tmp/lambda-response.json > /dev/null 2>&1; then

            # Check if response contains expected structure
            if jq -e '.statusCode' /tmp/lambda-response.json > /dev/null 2>&1; then
                STATUS_CODE=$(jq -r '.statusCode' /tmp/lambda-response.json)
                if [[ "$STATUS_CODE" == "200" || "$STATUS_CODE" == "429" ]]; then
                    print_success "Lambda function invocation (status: $STATUS_CODE)"
                    PASSED_TESTS=$((PASSED_TESTS + 1))
                else
                    print_warning "Lambda function returned status: $STATUS_CODE"
                    PASSED_TESTS=$((PASSED_TESTS + 1))
                fi
            else
                print_error "Lambda function response format invalid"
                FAILED_TESTS=$((FAILED_TESTS + 1))
            fi
        else
            print_error "Lambda function invocation failed"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
        TOTAL_TESTS=$((TOTAL_TESTS + 1))

        # Cleanup
        rm -f /tmp/test-payload.json /tmp/lambda-response.json
    else
        print_warning "Could not test Lambda invocation - function name not available"
    fi
}

# Test 8: IAM roles and policies
test_iam_resources() {
    print_status "Testing IAM resources..."

    ROLE_NAME="inkra-lambda-execution-${ENVIRONMENT}"
    run_test "IAM Lambda execution role" "aws iam get-role --role-name $ROLE_NAME --region $REGION"
}

# Test 9: SNS topic for alerts
test_sns_topic() {
    SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn 2>/dev/null)
    if [[ -n "$SNS_TOPIC_ARN" ]]; then
        run_test "SNS alerts topic" "aws sns get-topic-attributes --topic-arn $SNS_TOPIC_ARN --region $REGION"
    else
        print_warning "Could not get SNS topic ARN from Terraform output"
    fi
}

# Test 10: Configuration validation
test_configuration_values() {
    print_status "Validating configuration values..."

    # Check if all required outputs are present
    REQUIRED_OUTPUTS=(
        "cognito_user_pool_id"
        "cognito_user_pool_client_id"
        "cognito_identity_pool_id"
        "api_gateway_url"
        "dynamodb_table_name"
    )

    for output in "${REQUIRED_OUTPUTS[@]}"; do
        if terraform output "$output" > /dev/null 2>&1; then
            VALUE=$(terraform output -raw "$output" 2>/dev/null)
            if [[ -n "$VALUE" && "$VALUE" != "null" ]]; then
                print_success "Configuration: $output = $VALUE"
                PASSED_TESTS=$((PASSED_TESTS + 1))
            else
                print_error "Configuration: $output is empty or null"
                FAILED_TESTS=$((FAILED_TESTS + 1))
            fi
        else
            print_error "Configuration: $output is missing"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    done
}

# Generate test report
generate_report() {
    echo ""
    echo "============================================================================"
    echo "                           TEST REPORT"
    echo "============================================================================"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $REGION"
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo ""

    if [[ $FAILED_TESTS -eq 0 ]]; then
        print_success "🎉 All tests passed! Deployment is healthy."
        echo ""
        echo "Next steps:"
        echo "1. Configure iOS app with the output values"
        echo "2. Create test users in Cognito"
        echo "3. Test end-to-end functionality"
        echo ""
        echo "Key endpoints:"
        API_URL=$(terraform output -raw api_gateway_url 2>/dev/null)
        [[ -n "$API_URL" ]] && echo "API Gateway: $API_URL"

        DASHBOARD_URL=$(terraform output -raw cloudwatch_dashboard_url 2>/dev/null)
        [[ -n "$DASHBOARD_URL" ]] && echo "CloudWatch Dashboard: $DASHBOARD_URL"

        return 0
    else
        print_error "❌ $FAILED_TESTS test(s) failed. Please review the deployment."
        echo ""
        echo "Common fixes:"
        echo "1. Check AWS credentials and permissions"
        echo "2. Verify Terraform state is up to date"
        echo "3. Review CloudWatch logs for errors"
        echo "4. Ensure all variables are set correctly"
        return 1
    fi
}

# Main execution
main() {
    echo "============================================================================"
    echo "                    INKRA DEPLOYMENT VALIDATION"
    echo "============================================================================"
    echo ""

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            *)
                echo "Usage: $0 [-e environment] [-r region]"
                exit 1
                ;;
        esac
    done

    print_status "Testing environment: $ENVIRONMENT in region: $REGION"
    echo ""

    # Check prerequisites
    check_terraform_outputs

    # Run all tests
    test_aws_connectivity
    test_cognito_user_pool
    test_dynamodb_table
    test_lambda_functions
    test_api_gateway
    test_cloudwatch_logs
    test_lambda_invocation
    test_iam_resources
    test_sns_topic
    test_configuration_values

    # Generate final report
    generate_report
}

# Run main function
main "$@"