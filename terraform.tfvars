# Example Terraform variables file
# Copy this to terraform.tfvars and fill in your actual values

# AWS Configuration
aws_region = "us-east-1"  # Change to your preferred region
environment = "dev"       # dev, staging, or prod

# Google Gemini API Configuration
# Get your API key from: https://aistudio.google.com/app/apikey
gemini_api_key = "your-google-gemini-api-key-here"

# iOS App Configuration
ios_bundle_id = "com.inkra.app"  # Your actual iOS app bundle ID

# Rate Limiting Configuration
free_tier_daily_limit = 10      # Daily question limit for free users
premium_tier_daily_limit = 100  # Daily question limit for premium users

# API Gateway Throttling
api_throttle_rate_limit = 10    # Requests per second
api_throttle_burst_limit = 20   # Burst capacity