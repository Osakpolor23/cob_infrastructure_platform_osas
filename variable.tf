variable "region" {
  description = "The AWS region to deploy into"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "COB"
}

variable "environment" {
  description = "The environment of the project e.g dev, test, staging, prod"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block of the VPC"
  type        = string
}

variable "public_subnets" {
  description = "Map of public subnets to create"
  type = map(object({
    cidr_block        = string
    availability_zone = optional(string)
  }))
}

variable "private_subnets" {
  description = "Map of private subnets to create"
  type = map(object({
    cidr_block        = string
    availability_zone = optional(string)
  }))
}

variable "database_subnets" {
  description = "Map of database subnets to create"
  type = map(object({
    cidr_block        = string
    availability_zone = optional(string)
  }))
}

variable "ingress_rules" {
  description = "Ingress rules for the security group"
  type = list(object({
    description     = string
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string), [])
    security_groups = optional(list(string), [])
  }))
  default = []
}

variable "bucket_name" {
  description = "Base name for the S3 bucket (will be prefixed with project-environment and suffixed with a six-digit random string for uniqueness)"
  type        = string
}