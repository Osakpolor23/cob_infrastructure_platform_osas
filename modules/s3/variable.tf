variable "project_name" {
    description = "The name of the project"
    type = string
    default = "COB"
}

variable "environment" {
    description = "The environment of the project e.g dev, test, staging, prod"
    type = string

    validation {
    condition     = contains(["dev", "test", "staging", "prod"], lower(var.environment))
    error_message = "environment must be one of: dev, test, staging, prod (case-insensitive)"
  }
}

variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}
