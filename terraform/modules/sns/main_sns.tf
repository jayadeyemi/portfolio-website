resource "aws_sns_topic" "lambda_failures" {
  name = var.sns_topic_name
}

resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "lambda-error-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Triggers if the Lambda function returns errors"
  dimensions = {
    FunctionName = var.lambda_function_name
  }
  alarm_actions = [aws_sns_topic.lambda_failures.arn]
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.lambda_failures.arn
  protocol  = "email"
  endpoint  = var.sns_subscription_email
}