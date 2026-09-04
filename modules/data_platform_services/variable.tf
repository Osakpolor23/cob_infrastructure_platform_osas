variable "project_name" {
    description = "The name of the project"
    type = string
    default = "cob"
}

variable "environment" {
    description = "The environment of the project e.g dev, test, staging, prod"
    type = string

    validation {
    condition     = contains(["dev", "test", "staging", "prod"], lower(var.environment))
    error_message = "environment must be one of: dev, test, staging, prod (case-insensitive)"
  }
}

variable "data_bucket_name" {
  description = "Name of the existing S3 bucket holding source data (from S3 module)"
  type        = string
}

variable "crawler_schedule" {
  description = "Cron schedule for the Glue crawler (default is null for run on-demand)"
  type        = string
  default     = null
}

variable "glue_crawler_role_arn" {
  description = "IAM role ARN Glue assumes to read S3 and write the catalog (from IAM module)"
  type        = string
}

variable "query_results_retention_days" {
  description = "The number of days the query results will be retained on the target storage s3 bucket"
  type    = number
  default = 30
}