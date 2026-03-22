output "s3_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.bronze_bucket.bucket
}

output "kinesis_stream_name" {
  description = "The name of the Kinesis Data Stream"
  value       = aws_kinesis_stream.market_data_stream.name
}

output "producer_policy_arn" {
  description = "The ARN of the IAM Policy required by the local python producer"
  value       = aws_iam_policy.producer_policy.arn
}
