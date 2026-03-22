data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "${var.project_prefix}-redis-subnet"
  subnet_ids = data.aws_subnets.default.ids
}

resource "aws_security_group" "redis_sg" {
  name        = "${var.project_prefix}-redis-sg"
  description = "Security group for Redis cluster allowing Glue access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port = 6379
    to_port   = 6379
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "glue_sg" {
  name        = "${var.project_prefix}-glue-sg"
  description = "Security group for Glue Streaming Job"
  vpc_id      = data.aws_vpc.default.id

  # Required by Glue to communicate with itself
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "redis_allow_glue" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.glue_sg.id
  security_group_id        = aws_security_group.redis_sg.id
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_prefix}-redis"
  engine               = "redis"
  node_type            = "cache.t4g.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.1"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [aws_security_group.redis_sg.id]
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}
