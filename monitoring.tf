# SNS Topic for alerts
resource "aws_sns_topic" "inkra_alerts" {
  name = "${local.project_name}-alerts-${local.environment}"
  tags = local.common_tags
}

# Lambda Error Rate Alarms
resource "aws_cloudwatch_metric_alarm" "generate_questions_error_rate" {
  alarm_name          = "${local.project_name}-generate-questions-error-rate-${local.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors generate questions lambda error rate"
  alarm_actions       = [aws_sns_topic.inkra_alerts.arn]
  ok_actions         = [aws_sns_topic.inkra_alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.generate_questions.function_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "get_user_profile_error_rate" {
  alarm_name          = "${local.project_name}-get-user-profile-error-rate-${local.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors get user profile lambda error rate"
  alarm_actions       = [aws_sns_topic.inkra_alerts.arn]
  ok_actions         = [aws_sns_topic.inkra_alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.get_user_profile.function_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "update_user_preferences_error_rate" {
  alarm_name          = "${local.project_name}-update-user-preferences-error-rate-${local.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors update user preferences lambda error rate"
  alarm_actions       = [aws_sns_topic.inkra_alerts.arn]
  ok_actions         = [aws_sns_topic.inkra_alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.update_user_preferences.function_name
  }

  tags = local.common_tags
}

# Lambda Duration Alarms
resource "aws_cloudwatch_metric_alarm" "generate_questions_duration" {
  alarm_name          = "${local.project_name}-generate-questions-duration-${local.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "25000" # 25 seconds (83% of 30 second timeout)
  alarm_description   = "This metric monitors generate questions lambda duration"
  alarm_actions       = [aws_sns_topic.inkra_alerts.arn]
  ok_actions         = [aws_sns_topic.inkra_alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.generate_questions.function_name
  }

  tags = local.common_tags
}

# API Gateway Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "api_gateway_error_rate" {
  alarm_name          = "${local.project_name}-api-gateway-error-rate-${local.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors API Gateway 4xx error rate"
  alarm_actions       = [aws_sns_topic.inkra_alerts.arn]
  ok_actions         = [aws_sns_topic.inkra_alerts.arn]

  dimensions = {
    ApiName   = aws_api_gateway_rest_api.inkra_api.name
    Stage     = aws_api_gateway_stage.inkra_api_stage.stage_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_error_rate" {
  alarm_name          = "${local.project_name}-api-gateway-5xx-error-rate-${local.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors API Gateway 5xx error rate"
  alarm_actions       = [aws_sns_topic.inkra_alerts.arn]
  ok_actions         = [aws_sns_topic.inkra_alerts.arn]

  dimensions = {
    ApiName   = aws_api_gateway_rest_api.inkra_api.name
    Stage     = aws_api_gateway_stage.inkra_api_stage.stage_name
  }

  tags = local.common_tags
}

# API Gateway Latency Alarm
resource "aws_cloudwatch_metric_alarm" "api_gateway_latency" {
  alarm_name          = "${local.project_name}-api-gateway-latency-${local.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000" # 5 seconds
  alarm_description   = "This metric monitors API Gateway latency"
  alarm_actions       = [aws_sns_topic.inkra_alerts.arn]
  ok_actions         = [aws_sns_topic.inkra_alerts.arn]

  dimensions = {
    ApiName   = aws_api_gateway_rest_api.inkra_api.name
    Stage     = aws_api_gateway_stage.inkra_api_stage.stage_name
  }

  tags = local.common_tags
}

# DynamoDB Throttling Alarms
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttling_usage_table" {
  alarm_name          = "${local.project_name}-dynamodb-throttling-usage-${local.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors DynamoDB throttling on usage table"
  alarm_actions       = [aws_sns_topic.inkra_alerts.arn]
  ok_actions         = [aws_sns_topic.inkra_alerts.arn]

  dimensions = {
    TableName = aws_dynamodb_table.inkra_usage.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttling_sessions_table" {
  alarm_name          = "${local.project_name}-dynamodb-throttling-sessions-${local.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors DynamoDB throttling on sessions table"
  alarm_actions       = [aws_sns_topic.inkra_alerts.arn]
  ok_actions         = [aws_sns_topic.inkra_alerts.arn]

  dimensions = {
    TableName = aws_dynamodb_table.inkra_sessions.name
  }

  tags = local.common_tags
}

# Cost Budget Alert (optional)
resource "aws_budgets_budget" "inkra_monthly_budget" {
  name         = "${local.project_name}-monthly-budget-${local.environment}"
  budget_type  = "COST"
  limit_amount = "50"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  time_period_start = "2024-01-01_00:00"


  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type           = "PERCENTAGE"
    notification_type        = "ACTUAL"
    subscriber_email_addresses = [] # Add email addresses as needed
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type           = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [] # Add email addresses as needed
  }

  tags = local.common_tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "inkra_dashboard" {
  dashboard_name = "${local.project_name}-dashboard-${local.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.generate_questions.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.generate_questions.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.generate_questions.function_name]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Generate Questions Lambda Metrics"
          view   = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.inkra_api.name, "Stage", aws_api_gateway_stage.inkra_api_stage.stage_name],
            ["AWS/ApiGateway", "4XXError", "ApiName", aws_api_gateway_rest_api.inkra_api.name, "Stage", aws_api_gateway_stage.inkra_api_stage.stage_name],
            ["AWS/ApiGateway", "5XXError", "ApiName", aws_api_gateway_rest_api.inkra_api.name, "Stage", aws_api_gateway_stage.inkra_api_stage.stage_name]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "API Gateway Metrics"
          view   = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.inkra_usage.name],
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", aws_dynamodb_table.inkra_usage.name]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "DynamoDB Usage Table Metrics"
          view   = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.get_user_profile.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.update_user_preferences.function_name]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "User Management Lambda Metrics"
          view   = "timeSeries"
          stacked = false
        }
      }
    ]
  })
}