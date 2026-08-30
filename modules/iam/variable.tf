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

variable "data_bucket_arn" {
  description = "ARN of the main S3 data bucket (from S3 module)"
  type        = string
}

variable "athena_results_bucket_arn" {
  description = "ARN of the Athena query results bucket (from data platform module)"
  type        = string
}

variable "iam_users" {
  description = "Map of IAM users to create and which groups/console access they get"
  type = map(object({
    groups         = list(string)
    console_access = bool
  }))
  default = {}
}

variable "iam_group" {
  description = "The name of the group to be created"
  type = string
}
