resource "aws_iam_role" "glue_streaming_role" {
  name = "${var.project_prefix}-glue-streaming-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_streaming_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_kinesis_policy" {
  name = "${var.project_prefix}-glue-kinesis-policy"
  role = aws_iam_role.glue_streaming_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary"
        ]
        Resource = aws_kinesis_stream.market_data_stream.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:ListShards",
          "kinesis:ListStreams"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${aws_s3_bucket.glue_assets.bucket}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::${aws_s3_bucket.glue_assets.bucket}"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.glue_job_logs.arn,
          "${aws_cloudwatch_log_group.glue_job_logs.arn}:*",
          "arn:aws:logs:ap-southeast-2:969632167370:log-group:/aws-glue/jobs/*"
        ]
      }
    ]
  })
}

data "aws_subnet" "first" {
  id = data.aws_subnets.default.ids[0]
}

resource "aws_glue_connection" "redis_connection" {
  name = "${var.project_prefix}-redis-connection"

  connection_type = "NETWORK"

  physical_connection_requirements {
    availability_zone      = data.aws_subnet.first.availability_zone
    security_group_id_list = [aws_security_group.glue_sg.id]
    subnet_id              = data.aws_subnet.first.id
  }
}

resource "aws_s3_bucket" "glue_assets" {
  bucket        = "${var.s3_bucket_name}-glue-assets"
  force_destroy = true
}

resource "aws_s3_object" "streaming_job_script" {
  bucket = aws_s3_bucket.glue_assets.id
  key    = "scripts/streaming_job.py"
  source = "../glue/streaming_job.py"
  etag   = filemd5("../glue/streaming_job.py")
}

resource "aws_s3_object" "redis_lib" {
  bucket = aws_s3_bucket.glue_assets.id
  key    = "libs/redis-5.2.1-py3-none-any.whl"
  source = "../glue/libs/redis-5.2.1-py3-none-any.whl"
  etag   = filemd5("../glue/libs/redis-5.2.1-py3-none-any.whl")
}

resource "aws_s3_object" "query_redis_script" {
  bucket = aws_s3_bucket.glue_assets.id
  key    = "scripts/query_redis.py"
  source = "../glue/query_redis.py"
  etag   = filemd5("../glue/query_redis.py")
}

resource "aws_glue_job" "market_data_streaming" {
  name     = "${var.project_prefix}-streaming-job"
  role_arn = aws_iam_role.glue_streaming_role.arn

  connections = [aws_glue_connection.redis_connection.name]

  command {
    script_location = "s3://${aws_s3_bucket.glue_assets.id}/scripts/streaming_job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--continuous-log-logGroup"          = aws_cloudwatch_log_group.glue_job_logs.name
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = "true"
    "--REDIS_HOST"                       = aws_elasticache_cluster.redis.cache_nodes[0].address
    "--REDIS_PORT"                       = aws_elasticache_cluster.redis.port
    "--STREAM_ARN"                       = aws_kinesis_stream.market_data_stream.arn
    "--AWS_REGION"                       = var.aws_region
    "--TempDir"                          = "s3://${aws_s3_bucket.glue_assets.id}/tmp"
    "--extra-py-files"                   = "s3://${aws_s3_bucket.glue_assets.id}/libs/redis_lib.zip"
    "--extra-jars"                       = "s3://${aws_s3_bucket.glue_assets.id}/libs/spark-sql-kinesis.jar"
  }

  execution_class   = "STANDARD"
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
}

resource "aws_glue_job" "redis_query" {
  name     = "${var.project_prefix}-redis-query"
  role_arn = aws_iam_role.glue_streaming_role.arn

  connections = [aws_glue_connection.redis_connection.name]

  command {
    script_location = "s3://${aws_s3_bucket.glue_assets.id}/scripts/query_redis.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--continuous-log-logGroup"          = aws_cloudwatch_log_group.glue_redis_query_logs.name
    "--enable-continuous-cloudwatch-log" = "true"
    "--REDIS_HOST"                       = aws_elasticache_cluster.redis.cache_nodes[0].address
    "--REDIS_PORT"                       = aws_elasticache_cluster.redis.port
    "--extra-py-files"                   = "s3://${aws_s3_bucket.glue_assets.id}/libs/redis_lib.zip"
  }

  execution_class   = "STANDARD"
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
}

resource "aws_cloudwatch_log_group" "glue_redis_query_logs" {
  name              = "/aws-glue/jobs/${var.project_prefix}-redis-query"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "glue_job_logs" {
  name              = "/aws-glue/jobs/${var.project_prefix}-streaming-job"
  retention_in_days = 7
}
