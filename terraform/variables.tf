variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "project_prefix" {
  description = "Prefix to be used for all project resources"
  type        = string
  default     = "market-data"
}

variable "kinesis_stream_name" {
  description = "The name of the Kinesis Stream"
  type        = string
  default     = "binance-stream"
}

variable "s3_bucket_name" {
  description = "The S3 Bucket name for the Bronze layer (must be globally unique)"
  type        = string
  default     = "market-data-bronze-ksurineni-apse2" # Changed to avoid cross-region tombstone conflicts
}
