# IAM role for Lambda functions
resource "aws_iam_role" "lambda_execution_role" {
  name = "${local.project_name}-lambda-execution-role-${local.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Lambda basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

# Custom IAM policy for Lambda functions
resource "aws_iam_role_policy" "lambda_custom_policy" {
  name = "${local.project_name}-lambda-custom-policy-${local.environment}"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.inkra_usage.arn,
          "${aws_dynamodb_table.inkra_usage.arn}/index/*",
          aws_dynamodb_table.inkra_sessions.arn,
          "${aws_dynamodb_table.inkra_sessions.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:AdminGetUser",
          "cognito-idp:AdminUpdateUserAttributes",
          "cognito-idp:ListUsers"
        ]
        Resource = aws_cognito_user_pool.inkra_user_pool.arn
      }
    ]
  })
}

# Create deployment packages for Lambda functions
data "archive_file" "generate_questions_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-functions"
  output_path = "${path.module}/generate-questions.zip"
  excludes    = ["getUserProfile.js", "updateUserPreferences.js"]
}

data "archive_file" "get_user_profile_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-functions"
  output_path = "${path.module}/get-user-profile.zip"
  excludes    = ["generateQuestions.js", "updateUserPreferences.js"]
}

data "archive_file" "update_user_preferences_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-functions"
  output_path = "${path.module}/update-user-preferences.zip"
  excludes    = ["generateQuestions.js", "getUserProfile.js"]
}

# Lambda function: generateQuestions
resource "aws_lambda_function" "generate_questions" {
  filename         = data.archive_file.generate_questions_zip.output_path
  function_name    = "${local.project_name}-generate-questions-${local.environment}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "generateQuestions.handler"
  source_code_hash = data.archive_file.generate_questions_zip.output_base64sha256
  runtime         = "nodejs18.x"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      USAGE_TABLE            = aws_dynamodb_table.inkra_usage.name
      SESSIONS_TABLE         = aws_dynamodb_table.inkra_sessions.name
      USER_POOL_ID          = aws_cognito_user_pool.inkra_user_pool.id
      GEMINI_API_KEY        = var.gemini_api_key
      FREE_TIER_DAILY_LIMIT = var.free_tier_daily_limit
      PREMIUM_TIER_DAILY_LIMIT = var.premium_tier_daily_limit
    }
  }

  tags = merge(local.common_tags, {
    Function = "Generate interview questions"
  })
}

# Lambda function: getUserProfile
resource "aws_lambda_function" "get_user_profile" {
  filename         = data.archive_file.get_user_profile_zip.output_path
  function_name    = "${local.project_name}-get-user-profile-${local.environment}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "getUserProfile.handler"
  source_code_hash = data.archive_file.get_user_profile_zip.output_base64sha256
  runtime         = "nodejs18.x"
  timeout         = 15
  memory_size     = 128

  environment {
    variables = {
      USAGE_TABLE    = aws_dynamodb_table.inkra_usage.name
      SESSIONS_TABLE = aws_dynamodb_table.inkra_sessions.name
      USER_POOL_ID   = aws_cognito_user_pool.inkra_user_pool.id
    }
  }

  tags = merge(local.common_tags, {
    Function = "Get user profile and usage stats"
  })
}

# Lambda function: updateUserPreferences
resource "aws_lambda_function" "update_user_preferences" {
  filename         = data.archive_file.update_user_preferences_zip.output_path
  function_name    = "${local.project_name}-update-user-preferences-${local.environment}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "updateUserPreferences.handler"
  source_code_hash = data.archive_file.update_user_preferences_zip.output_base64sha256
  runtime         = "nodejs18.x"
  timeout         = 15
  memory_size     = 128

  environment {
    variables = {
      USER_POOL_ID = aws_cognito_user_pool.inkra_user_pool.id
    }
  }

  tags = merge(local.common_tags, {
    Function = "Update user preferences"
  })
}

# CloudWatch Log Groups for Lambda functions
resource "aws_cloudwatch_log_group" "generate_questions_logs" {
  name              = "/aws/lambda/${aws_lambda_function.generate_questions.function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "get_user_profile_logs" {
  name              = "/aws/lambda/${aws_lambda_function.get_user_profile.function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "update_user_preferences_logs" {
  name              = "/aws/lambda/${aws_lambda_function.update_user_preferences.function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}