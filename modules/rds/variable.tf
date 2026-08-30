variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  description = "VPC ID (from networking module)"
  type        = string
}

variable "database_subnet_ids" {
  description = "Database subnet IDs (from networking module)"
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Security group ID of the app tier allowed to reach the DB"
  type        = string
}

variable "db_name" {
  type    = string
  default = "appdb_instance"
}

variable "master_username" {
  type    = string
  default = "postgres_admin"
}

variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "parameter_group_family" {
  type    = string
  default = "postgres16"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "storage_type" {
  type    = string
  default = "gp3"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  type    = number
  default = 3000
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "skip_final_snapshot" {
  type    = bool
  default = false
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

variable "backup_window" {
  type    = string
  default = "00:00-01:00"
}

variable "maintenance_window" {
  type    = string
  default = "sun:10:30-sun:11:30"
}

variable "performance_insights_enabled" {
  type    = bool
  default = false
}