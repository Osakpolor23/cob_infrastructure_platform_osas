resource "random_password" "master_password" {
  length  = 24
  special = false
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = lower("${local.resource_name}-db-subnet-group")
  subnet_ids = var.database_subnet_ids

  tags = {
    Name = "${local.resource_name}-db-subnet-group"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "${local.resource_name}-rds-sg"
  description = "Allow PostgreSQL access from app tier only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from app security group"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.app_security_group_id] 
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.resource_name}-rds-sg"
  }
}

resource "aws_db_parameter_group" "postgres_params" {
  name   = "${local.resource_name}-postgres-params"
  family = var.parameter_group_family

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "postgres" {
  identifier     = "${local.resource_name}-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.master_username
  password = random_password.master_password.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  parameter_group_name   = aws_db_parameter_group.postgres_params.name

  multi_az                     = var.multi_az
  publicly_accessible          = false
  deletion_protection          = var.deletion_protection
  skip_final_snapshot          = var.skip_final_snapshot
  final_snapshot_identifier    = var.skip_final_snapshot ? null : "${local.resource_name}-final-snapshot"
  backup_retention_period       = var.backup_retention_period
  backup_window                 = var.backup_window
  maintenance_window             = var.maintenance_window
  performance_insights_enabled  = var.performance_insights_enabled
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade", "iam-db-auth-error"]
  # iam-db-auth-error included pre-emptively for future IAM DB auth support;
  # currently inactive since iam_database_authentication_enabled is not set
  tags = {
    Name = "${local.resource_name}-postgres"
  }
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${local.resource_name}-db-credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master_password.result
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = 5432
    dbname   = var.db_name
  })
}
