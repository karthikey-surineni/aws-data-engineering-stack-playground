data "aws_route_tables" "default" {
  vpc_id = data.aws_vpc.default.id
}

# Interface endpoints must accept HTTPS from any VPC client (Glue workers, ECS Fargate, etc.).
# Do not reuse glue_sg here: that SG is for Glue ENIs; mixing it with endpoint ENIs made
# cross-SG rules fragile for ECS → CloudWatch Logs (ResourceInitializationError).
resource "aws_security_group" "vpc_interface_endpoints" {
  name        = "${var.project_prefix}-vpc-endpoints-sg"
  description = "HTTPS from VPC to interface VPC endpoints (Glue, ECS awslogs, etc.)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTPS to AWS API interface endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# AWS Glue needs S3 to download the script
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = data.aws_vpc.default.id
  service_name    = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = data.aws_route_tables.default.ids
}

# Glue Job needs Kinesis to read the stream
resource "aws_vpc_endpoint" "kinesis" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.${var.aws_region}.kinesis-streams"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [data.aws_subnet.first.id]
  security_group_ids  = [aws_security_group.vpc_interface_endpoints.id]
  private_dns_enabled = true
}

# CloudWatch Logs interface endpoint (Glue + ECS Fargate awslogs driver use private DNS).
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.default.ids
  security_group_ids  = [aws_security_group.vpc_interface_endpoints.id]
  private_dns_enabled = true
}
# Glue Job needs Monitoring to write metrics
resource "aws_vpc_endpoint" "monitoring" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.${var.aws_region}.monitoring"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [data.aws_subnet.first.id]
  security_group_ids  = [aws_security_group.vpc_interface_endpoints.id]
  private_dns_enabled = true
}

# Glue service endpoint — allows Glue workers to bootstrap connectors
resource "aws_vpc_endpoint" "glue" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.${var.aws_region}.glue"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [data.aws_subnet.first.id]
  security_group_ids  = [aws_security_group.vpc_interface_endpoints.id]
  private_dns_enabled = true
}
# Glue Job needs STS to resolve Identity
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [data.aws_subnet.first.id]
  security_group_ids  = [aws_security_group.vpc_interface_endpoints.id]
  private_dns_enabled = true
}
