provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

resource "aws_kinesis_stream" "market_data_stream" {
  name             = "${var.project_prefix}-${var.kinesis_stream_name}"
  shard_count      = 1
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}

resource "aws_s3_bucket" "bronze_bucket" {
  bucket        = var.s3_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "bronze_bucket_pab" {
  bucket                  = aws_s3_bucket.bronze_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Role for Firehose to write to S3
resource "aws_iam_role" "firehose_role" {
  name = "${var.project_prefix}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "firehose_policy" {
  name = "${var.project_prefix}-firehose-policy"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.bronze_bucket.arn,
          "${aws_s3_bucket.bronze_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ]
        Resource = aws_kinesis_stream.market_data_stream.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.firehose_log_group.arn,
          "${aws_cloudwatch_log_group.firehose_log_group.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "s3_stream" {
  name        = "${var.project_prefix}-firehose-s3-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.bronze_bucket.arn

    # Prefix mapping
    prefix              = "raw/binance/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/!{firehose:error-output-type}/"

    buffering_size     = 5
    buffering_interval = 60

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_log_group.name
      log_stream_name = aws_cloudwatch_log_stream.firehose_log_stream.name
    }
  }

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.market_data_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }
}

# IAM Policy for the local Python Producer
# Here we are just creating a policy that an existing user or role could use.
# For simplicity, we create a policy that the user can attach to their local AWS credential's user.
resource "aws_iam_policy" "producer_policy" {
  name        = "${var.project_prefix}-producer-policy"
  description = "Policy for local Python producer to write to Kinesis"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = aws_kinesis_stream.market_data_stream.arn
      }
    ]
  })
}
