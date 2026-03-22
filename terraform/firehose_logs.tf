resource "aws_cloudwatch_log_group" "firehose_log_group" {
  name              = "/aws/kinesisfirehose/${var.project_prefix}-firehose-s3-stream"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_stream" "firehose_log_stream" {
  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.firehose_log_group.name
}
