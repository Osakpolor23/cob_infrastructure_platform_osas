output "db_instance_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "db_instance_id" {
  value = aws_db_instance.postgres.id
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding DB credentials — apps should fetch from here, never from tfvars/state"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "rds_security_group_id" {
  value = aws_security_group.rds_sg.id
}