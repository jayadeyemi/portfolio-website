resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name                = var.cloudwatch_event_rule_name
  description         = "Trigger Lambda function every 3 days at 03:00 UTC"
  schedule_expression = "rate(3 days)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.lambda_schedule.name
  target_id = var.lambda_function_name
  arn       = var.lambda_function_arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule.arn
}
