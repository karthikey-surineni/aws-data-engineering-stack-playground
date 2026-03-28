# SNS Topic for pipeline alerts
resource "aws_sns_topic" "pipeline_alerts" {
  name = "${var.project_prefix}-pipeline-alerts"
}

# CloudWatch Alarm for Kinesis Iterator Age (Consumer Lag)
resource "aws_cloudwatch_metric_alarm" "kinesis_iterator_age" {
  alarm_name          = "${var.project_prefix}-kinesis-iterator-age-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "GetRecords.IteratorAgeMilliseconds"
  namespace           = "AWS/Kinesis"
  period              = 60
  statistic           = "Maximum"
  threshold           = 60000 # 60 seconds of lag

  dimensions = {
    StreamName = aws_kinesis_stream.market_data_stream.name
  }

  alarm_description = "This metric monitors the iterator age for Kinesis consumers. Triggers if consumer is lagging by more than 1 minute."
  actions_enabled   = true

  alarm_actions = [aws_sns_topic.pipeline_alerts.arn]
  ok_actions    = [aws_sns_topic.pipeline_alerts.arn]
}

# CloudWatch Alarm for Firehose S3 Delivery Success
resource "aws_cloudwatch_metric_alarm" "firehose_delivery_success" {
  alarm_name          = "${var.project_prefix}-firehose-delivery-success-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DeliveryToS3.Success"
  namespace           = "AWS/Firehose"
  period              = 300 # 5 minutes
  statistic           = "Average"
  threshold           = 100 # Alert if success rate falls below 100%

  dimensions = {
    DeliveryStreamName = aws_kinesis_firehose_delivery_stream.s3_stream.name
  }

  alarm_description = "Monitors Firehose delivery success rate to S3. Alerts if not 100% successful over 5 minutes."
  actions_enabled   = true

  alarm_actions = [aws_sns_topic.pipeline_alerts.arn]
  ok_actions    = [aws_sns_topic.pipeline_alerts.arn]
}

# CloudWatch Alarm for Glue Streaming Job failures
resource "aws_cloudwatch_metric_alarm" "glue_job_failure" {
  alarm_name          = "${var.project_prefix}-glue-job-failure-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "glue.driver.aggregate.numFailedTasks"
  namespace           = "Glue"
  period              = 300
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    JobName = aws_glue_job.market_data_streaming.name
    JobRunId = "ALL"
    Type     = "gauge"
  }

  alarm_description = "Alerts when the Glue streaming job has failed tasks."
  actions_enabled   = true

  alarm_actions = [aws_sns_topic.pipeline_alerts.arn]
}

# CloudWatch Alarm for ECS dbt task failures
resource "aws_cloudwatch_metric_alarm" "ecs_task_failure" {
  alarm_name          = "${var.project_prefix}-ecs-dbt-task-failure-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.dbt_orchestrator.arn
  }

  alarm_description = "Alerts when the dbt Step Functions execution fails."
  actions_enabled   = true

  alarm_actions = [aws_sns_topic.pipeline_alerts.arn]
}
