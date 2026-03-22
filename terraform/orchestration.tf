# Phase 4 Infrastructure: ECR, ECS, and Step Functions

resource "aws_ecr_repository" "dbt_repo" {
  name                 = "${var.project_prefix}-dbt-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_cluster" "dbt_cluster" {
  name = "${var.project_prefix}-dbt-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/aws/ecs/${var.project_prefix}-dbt-task"
  retention_in_days = 7
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_prefix}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Scoped CloudWatch Logs permissions for the awslogs driver (DescribeLogGroups during init, etc.).
# Complements the managed execution policy when validating log configuration against this log group.
resource "aws_iam_role_policy" "ecs_task_execution_cloudwatch_logs" {
  name = "${var.project_prefix}-ecs-exec-cwl"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.ecs_logs.arn,
          "${aws_cloudwatch_log_group.ecs_logs.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_security_group" "ecs_sg" {
  name        = "${var.project_prefix}-ecs-sg"
  description = "Security group for dbt ECS task"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Task role needs Athena, S3, and Glue permissions for dbt
resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "${var.project_prefix}-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:GetWorkGroup",
          "athena:ListWorkGroups",
          "athena:GetDataCatalog",
          "athena:ListDataCatalogs",
          "athena:ListDatabases",
          "athena:ListTableMetadata",
          "athena:GetTableMetadata"
        ]
        Resource = "*" # Restrict to workgroup if needed
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:AbortMultipartUpload",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.bronze_bucket.arn,
          "${aws_s3_bucket.bronze_bucket.arn}/*",
          aws_s3_bucket.athena_query_results.arn,
          "${aws_s3_bucket.athena_query_results.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable"
        ]
        Resource = [
          aws_glue_catalog_database.market_data_db.arn,
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.market_data_db.name}/*"
        ]
      }
    ]
  })
}

resource "aws_ecs_task_definition" "dbt_task" {
  family                   = "${var.project_prefix}-dbt-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  # dbt + Athena Iceberg needs more than 512 MiB; OOM kills look like "lost" CloudWatch logs mid-run.
  cpu                = "512"
  memory             = "2048"
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "dbt-container"
      image     = "${aws_ecr_repository.dbt_repo.repository_url}:latest"
      essential = true
      environment = [
        { name = "PYTHONUNBUFFERED", value = "1" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "dbt"
          "awslogs-create-group"  = "true"
          # Avoid blocking the dbt process when CloudWatch Logs API is slow or briefly unavailable.
          "mode"            = "non-blocking"
          "max-buffer-size" = "25m"
        }
      }
    }
  ])
}

# Step Function State Machine
resource "aws_iam_role" "sfn_role" {
  name = "${var.project_prefix}-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "sfn_policy" {
  name = "${var.project_prefix}-sfn-policy"
  role = aws_iam_role.sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = aws_ecs_task_definition.dbt_task.arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "events:PutTargets",
          "events:PutRule",
          "events:DescribeRule"
        ],
        Resource = [
          "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForECSTaskRule"
        ]
      }
    ]
  })
}

resource "aws_sfn_state_machine" "dbt_orchestrator" {
  name     = "${var.project_prefix}-dbt-orchestrator"
  role_arn = aws_iam_role.sfn_role.arn

  definition = jsonencode({
    StartAt = "RunDbtTask"
    States = {
      RunDbtTask = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"
        Parameters = {
          LaunchType     = "FARGATE"
          Cluster        = aws_ecs_cluster.dbt_cluster.arn
          TaskDefinition = aws_ecs_task_definition.dbt_task.arn
          NetworkConfiguration = {
            AwsvpcConfiguration = {
              Subnets        = data.aws_subnets.default.ids
              SecurityGroups = [aws_security_group.ecs_sg.id]
              AssignPublicIp = "ENABLED"
            }
          }
        }
        End = true
      }
    }
  })
}

# EventBridge Rule (Every 10 minutes)
resource "aws_cloudwatch_event_rule" "dbt_schedule" {
  name                = "${var.project_prefix}-dbt-schedule"
  description         = "Triggers dbt transformation every 10 minutes"
  schedule_expression = "rate(10 minutes)"
}

resource "aws_cloudwatch_event_target" "dbt_target" {
  rule      = aws_cloudwatch_event_rule.dbt_schedule.name
  target_id = "TriggerStepFunction"
  arn       = aws_sfn_state_machine.dbt_orchestrator.arn
  role_arn  = aws_iam_role.eventbridge_sfn_role.arn
}

resource "aws_iam_role" "eventbridge_sfn_role" {
  name = "${var.project_prefix}-eventbridge-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_sfn_policy" {
  name = "${var.project_prefix}-eventbridge-sfn-policy"
  role = aws_iam_role.eventbridge_sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = aws_sfn_state_machine.dbt_orchestrator.arn
      }
    ]
  })
}
