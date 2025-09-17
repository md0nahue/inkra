# DynamoDB table for rate limiting and usage tracking
resource "aws_dynamodb_table" "inkra_usage" {
  name           = "${local.project_name}-usage-${local.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user_id"
  range_key      = "date_hour"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "date_hour"
    type = "S"
  }

  attribute {
    name = "date"
    type = "S"
  }

  attribute {
    name = "subscription_tier"
    type = "S"
  }

  # Global Secondary Index for date-based queries
  global_secondary_index {
    name            = "DateIndex"
    hash_key        = "date"
    range_key       = "user_id"
    projection_type = "ALL"
  }

  # Global Secondary Index for subscription tier analytics
  global_secondary_index {
    name            = "SubscriptionTierIndex"
    hash_key        = "subscription_tier"
    range_key       = "date"
    projection_type = "ALL"
  }

  # TTL for automatic cleanup of old records (90 days)
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  tags = merge(local.common_tags, {
    Purpose = "Usage tracking and rate limiting"
  })
}

# DynamoDB table for user sessions and temporary data
resource "aws_dynamodb_table" "inkra_sessions" {
  name           = "${local.project_name}-sessions-${local.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  # GSI for user-based session queries
  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "user_id"
    projection_type = "ALL"
  }

  # TTL for automatic session cleanup (24 hours)
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  tags = merge(local.common_tags, {
    Purpose = "User sessions and temporary data"
  })
}