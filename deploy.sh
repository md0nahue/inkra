#!/bin/bash

# ============================================================================
# INKRA AWS DEPLOYMENT SCRIPT
# Deploys complete serverless infrastructure to AWS
# ============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="dev"
AWS_REGION="us-east-1"
SKIP_DEPS=false
DESTROY=false
PLAN_ONLY=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploys Inkra AWS infrastructure using Terraform

OPTIONS:
    -e, --environment ENV    Environment to deploy (dev, staging, prod) [default: dev]
    -r, --region REGION      AWS region [default: us-east-1]
    -s, --skip-deps         Skip dependency installation
    -d, --destroy           Destroy infrastructure instead of creating
    -p, --plan              Show plan only, don't apply
    -h, --help              Show this help message

EXAMPLES:
    $0                      # Deploy to dev environment
    $0 -e prod -r us-west-2 # Deploy to prod in us-west-2
    $0 -d                   # Destroy dev environment
    $0 -p                   # Show plan for dev environment

PREREQUISITES:
    - AWS CLI configured with appropriate permissions
    - Terraform >= 1.0 installed
    - Node.js >= 18 for Lambda functions
    - Gemini API key set in terraform.tfvars

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -s|--skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        -d|--destroy)
            DESTROY=true
            shift
            ;;
        -p|--plan)
            PLAN_ONLY=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Environment must be one of: dev, staging, prod"
    exit 1
fi

print_status "Starting Inkra deployment..."
print_status "Environment: $ENVIRONMENT"
print_status "Region: $AWS_REGION"

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install AWS CLI first."
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Run 'aws configure' first."
        exit 1
    fi

    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform not found. Please install Terraform >= 1.0 first."
        exit 1
    fi

    # Check Terraform version
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    print_status "Terraform version: $TERRAFORM_VERSION"

    # Check Node.js for Lambda functions
    if ! command -v node &> /dev/null; then
        print_error "Node.js not found. Please install Node.js >= 18 first."
        exit 1
    fi

    NODE_VERSION=$(node --version)
    print_status "Node.js version: $NODE_VERSION"

    # Check if terraform.tfvars exists
    if [[ ! -f "terraform.tfvars" ]]; then
        print_warning "terraform.tfvars not found. Creating from example..."
        if [[ -f "terraform.tfvars.example" ]]; then
            cp terraform.tfvars.example terraform.tfvars
            print_warning "Please edit terraform.tfvars and add your Gemini API key before proceeding."
            print_warning "Run: terraform.tfvars and set gemini_api_key = \"your-key-here\""
            exit 1
        else
            print_error "terraform.tfvars.example not found. Cannot proceed."
            exit 1
        fi
    fi

    print_success "Prerequisites check passed"
}

# Install Lambda dependencies
install_lambda_deps() {
    if [[ "$SKIP_DEPS" == "true" ]]; then
        print_status "Skipping dependency installation"
        return
    fi

    print_status "Installing Lambda function dependencies..."

    if [[ -d "lambda-functions" ]]; then
        cd lambda-functions

        # Check if package.json exists
        if [[ -f "package.json" ]]; then
            print_status "Installing Node.js dependencies..."
            npm install --production
            print_success "Lambda dependencies installed"
        else
            print_warning "No package.json found in lambda-functions directory"
        fi

        cd ..
    else
        print_error "lambda-functions directory not found"
        exit 1
    fi
}

# Initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."

    # Initialize with backend configuration for state management
    terraform init \
        -backend-config="key=inkra/terraform-${ENVIRONMENT}.tfstate" \
        -backend-config="region=${AWS_REGION}"

    print_success "Terraform initialized"
}

# Plan deployment
plan_deployment() {
    print_status "Creating deployment plan..."

    terraform plan \
        -var="environment=${ENVIRONMENT}" \
        -var="aws_region=${AWS_REGION}" \
        -var-file="terraform.tfvars" \
        -out="tfplan-${ENVIRONMENT}"

    print_success "Deployment plan created"
}

# Apply deployment
apply_deployment() {
    if [[ "$PLAN_ONLY" == "true" ]]; then
        print_status "Plan-only mode enabled. Skipping apply."
        return
    fi

    print_status "Applying deployment..."

    terraform apply "tfplan-${ENVIRONMENT}"

    print_success "Deployment applied successfully!"
}

# Destroy infrastructure
destroy_infrastructure() {
    print_warning "This will DESTROY all infrastructure for environment: $ENVIRONMENT"
    read -p "Are you sure? Type 'yes' to confirm: " -r
    echo
    if [[ $REPLY != "yes" ]]; then
        print_status "Destruction cancelled"
        exit 0
    fi

    print_status "Destroying infrastructure..."

    terraform destroy \
        -var="environment=${ENVIRONMENT}" \
        -var="aws_region=${AWS_REGION}" \
        -var-file="terraform.tfvars" \
        -auto-approve

    print_success "Infrastructure destroyed"
}

# Show deployment outputs
show_outputs() {
    if [[ "$DESTROY" == "true" || "$PLAN_ONLY" == "true" ]]; then
        return
    fi

    print_status "Deployment outputs:"
    terraform output -json | jq '.'

    print_status "iOS SDK Configuration:"
    terraform output -json ios_sdk_configuration | jq '.'

    print_status "API Gateway URL:"
    terraform output -raw api_gateway_url

    print_status "CloudWatch Dashboard:"
    terraform output -raw cloudwatch_dashboard_url
}

# Validate Lambda functions
validate_lambdas() {
    if [[ "$DESTROY" == "true" || "$PLAN_ONLY" == "true" ]]; then
        return
    fi

    print_status "Validating Lambda functions..."

    # Get function names from Terraform output
    GENERATE_FUNCTION=$(terraform output -json lambda_function_names | jq -r '.value.generate_questions')
    PROFILE_FUNCTION=$(terraform output -json lambda_function_names | jq -r '.value.user_profile')
    PREFERENCES_FUNCTION=$(terraform output -json lambda_function_names | jq -r '.value.update_preferences')

    # Test each function
    print_status "Testing Lambda functions..."

    for func in "$GENERATE_FUNCTION" "$PROFILE_FUNCTION" "$PREFERENCES_FUNCTION"; do
        if aws lambda get-function --function-name "$func" --region "$AWS_REGION" &> /dev/null; then
            print_success "✓ $func is deployed and accessible"
        else
            print_error "✗ $func failed validation"
        fi
    done
}

# Test API Gateway
test_api_gateway() {
    if [[ "$DESTROY" == "true" || "$PLAN_ONLY" == "true" ]]; then
        return
    fi

    print_status "Testing API Gateway..."

    API_URL=$(terraform output -raw api_gateway_url)

    # Test CORS preflight
    if curl -s -o /dev/null -w "%{http_code}" -X OPTIONS "$API_URL/questions/generate" | grep -q "200"; then
        print_success "✓ API Gateway CORS is working"
    else
        print_warning "⚠ API Gateway CORS may need configuration"
    fi

    print_status "API Gateway URL: $API_URL"
}

# Main execution
main() {
    check_prerequisites

    if [[ "$DESTROY" == "true" ]]; then
        init_terraform
        destroy_infrastructure
        exit 0
    fi

    install_lambda_deps
    init_terraform
    plan_deployment
    apply_deployment
    show_outputs
    validate_lambdas
    test_api_gateway

    print_success "🚀 Inkra deployment completed successfully!"
    print_status "Next steps:"
    print_status "1. Test the API endpoints with Postman or curl"
    print_status "2. Configure iOS app with the output values"
    print_status "3. Monitor the CloudWatch dashboard for metrics"
    print_status ""
    print_status "API Gateway URL: $(terraform output -raw api_gateway_url 2>/dev/null || echo 'Not available')"
}

# Run main function
main "$@"