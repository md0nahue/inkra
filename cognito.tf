# AWS Cognito User Pool for authentication
resource "aws_cognito_user_pool" "inkra_user_pool" {
  name = "${local.project_name}-user-pool-${local.environment}"

  # Authentication attributes
  username_attributes = ["email"]

  # Password policy
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = false
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  # Custom attributes for subscription management
  schema {
    name                = "subscription_tier"
    attribute_data_type = "String"
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 20
    }
  }

  schema {
    name                = "monthly_quota"
    attribute_data_type = "Number"
    mutable             = true

    number_attribute_constraints {
      min_value = 0
      max_value = 10000
    }
  }

  schema {
    name                = "voice_preference"
    attribute_data_type = "String"
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  # Email verification
  auto_verified_attributes = ["email"]

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # MFA configuration
  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # User pool add-ons
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  # Verification message template
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Your Inkra verification code"
    email_message        = "Your verification code is {####}"
  }

  tags = local.common_tags
}

# User Pool Client for iOS app
resource "aws_cognito_user_pool_client" "inkra_ios_client" {
  name         = "${local.project_name}-ios-client-${local.environment}"
  user_pool_id = aws_cognito_user_pool.inkra_user_pool.id

  # OAuth configuration
  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]

  callback_urls = [
    "${var.ios_bundle_id}://auth"
  ]

  logout_urls = [
    "${var.ios_bundle_id}://logout"
  ]

  # Supported identity providers
  supported_identity_providers = ["COGNITO"]

  # Token validity
  access_token_validity  = 60   # 1 hour
  id_token_validity      = 60   # 1 hour
  refresh_token_validity = 30   # 30 days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Client settings
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"

  # Read and write attributes
  read_attributes = [
    "email",
    "email_verified",
    "preferred_username",
    "custom:subscription_tier",
    "custom:monthly_quota",
    "custom:voice_preference"
  ]

  write_attributes = [
    "email",
    "preferred_username",
    "custom:subscription_tier",
    "custom:monthly_quota",
    "custom:voice_preference"
  ]
}

# User Pool Domain for hosted UI (optional but recommended)
resource "aws_cognito_user_pool_domain" "inkra_domain" {
  domain       = "${local.project_name}-${local.environment}-${random_string.domain_suffix.result}"
  user_pool_id = aws_cognito_user_pool.inkra_user_pool.id
}

resource "random_string" "domain_suffix" {
  length  = 8
  special = false
  upper   = false
}

# User Groups for subscription tiers
resource "aws_cognito_user_group" "free_tier" {
  name         = "free_tier"
  user_pool_id = aws_cognito_user_pool.inkra_user_pool.id
  description  = "Free tier users with limited daily quota"
  precedence   = 2

  role_arn = aws_iam_role.free_tier_role.arn
}

resource "aws_cognito_user_group" "premium_tier" {
  name         = "premium_tier"
  user_pool_id = aws_cognito_user_pool.inkra_user_pool.id
  description  = "Premium tier users with higher daily quota"
  precedence   = 1

  role_arn = aws_iam_role.premium_tier_role.arn
}

# IAM roles for user groups
resource "aws_iam_role" "free_tier_role" {
  name = "${local.project_name}-free-tier-role-${local.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.inkra_identity_pool.id
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role" "premium_tier_role" {
  name = "${local.project_name}-premium-tier-role-${local.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.inkra_identity_pool.id
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Cognito Identity Pool for AWS SDK access
resource "aws_cognito_identity_pool" "inkra_identity_pool" {
  identity_pool_name               = "${local.project_name}-identity-pool-${local.environment}"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.inkra_ios_client.id
    provider_name           = aws_cognito_user_pool.inkra_user_pool.endpoint
    server_side_token_check = false
  }

  tags = local.common_tags
}

# Identity Pool Role Attachment
resource "aws_cognito_identity_pool_roles_attachment" "inkra_identity_pool_roles" {
  identity_pool_id = aws_cognito_identity_pool.inkra_identity_pool.id

  roles = {
    "authenticated" = aws_iam_role.authenticated_role.arn
  }

  role_mapping {
    identity_provider         = "${aws_cognito_user_pool.inkra_user_pool.endpoint}:${aws_cognito_user_pool_client.inkra_ios_client.id}"
    ambiguous_role_resolution = "AuthenticatedRole"
    type                      = "Token"
  }
}

# Authenticated role for identity pool
resource "aws_iam_role" "authenticated_role" {
  name = "${local.project_name}-authenticated-role-${local.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.inkra_identity_pool.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for authenticated users
resource "aws_iam_role_policy" "authenticated_policy" {
  name = "${local.project_name}-authenticated-policy-${local.environment}"
  role = aws_iam_role.authenticated_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "execute-api:Invoke"
        ]
        Resource = "${aws_api_gateway_rest_api.inkra_api.execution_arn}/*"
      }
    ]
  })
}