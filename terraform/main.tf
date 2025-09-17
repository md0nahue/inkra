# Terraform configuration for Inkra iOS app backend infrastructure
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values
locals {
  project_name = "inkra"
  environment  = var.environment
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}