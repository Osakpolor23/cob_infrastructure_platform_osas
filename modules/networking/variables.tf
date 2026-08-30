variable "region" {
  description = "The AWS region to deploy into"
  type        = string
}

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

variable "vpc_cidr" {
    description = "The cidr block of the vpc"
    type = string
}

variable "public_subnets" {
    description = "Map of public subnets to create."
    type = map(object({
        cidr_block        = string
        availability_zone = optional(string)
  }))
}

variable "private_subnets" {
    description = "Map of private subnets to create."
    type = map(object({
        cidr_block        = string
        availability_zone = optional(string)
  }))
}

variable "database_subnets" {
  description = "Map of database subnets to create."
  type = map(object({
    cidr_block        = string
    availability_zone = optional(string)
  }))
}

variable "name_suffix" {
  description = "Suffix appended to the project name for the SG name (e.g. 'rds-sg')"
  type        = string
  default     = "sg"
}

variable "description" {
  description = "Description of the security group"
  type        = string
  default     = "Security group deployed using COB Terraform Modules"
}


variable "ingress_rules" {
  description = "List of ingress rules to apply. Set cidr_blocks for CIDR-based access and/or security_groups for SG-to-SG access."
  type = list(object({
    description     = string
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string), [])  # the optional object type takes two arguments, Type(reguired) and Default(optional)
    security_groups = optional(list(string), [])
  }))
  default = []  # Deny all by default
}

variable "egress_rules" {
  description = "List of egress rules to apply. Set cidr_blocks for CIDR-based access and/or security_groups for SG-to-SG access."
  type = list(object({
    description     = string
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string), [])
    security_groups = optional(list(string), [])
  }))
  default = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"    # All protocols
      cidr_blocks = ["0.0.0.0/0"]  # From anywhere
    }
  ]
}