variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "gemini_api_key" {
  description = "Google Gemini API key for question generation"
  type        = string
  sensitive   = true
}

variable "ios_bundle_id" {
  description = "iOS app bundle identifier"
  type        = string
  default     = "com.inkra.app"
}

variable "free_tier_daily_limit" {
  description = "Daily question limit for free tier users"
  type        = number
  default     = 10
}

variable "premium_tier_daily_limit" {
  description = "Daily question limit for premium tier users"
  type        = number
  default     = 100
}

variable "api_throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 10
}

variable "api_throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 20
}