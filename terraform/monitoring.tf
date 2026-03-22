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
  actions_enabled   = false # Enable this when SNS topic is available
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
  actions_enabled   = false
}
