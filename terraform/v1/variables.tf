# V1 Variables - Minimal configuration

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "inkra"
}

variable "gemini_api_key" {
  description = "Google Gemini API key for AI question generation"
  type        = string
  sensitive   = true
}