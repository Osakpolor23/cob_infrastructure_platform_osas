variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, test, staging, prod)"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs — used by the public EC2 tier"
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "Private subnet IDs — used by the private EC2 tier and ECS"
  type        = list(string)
}

variable "public_security_group_id" {
  description = "Security group ID for the public-facing EC2 tier"
  type        = string
  default     = null
}

variable "private_security_group_id" {
  description = "Security group ID for the private EC2 tier and ECS"
  type        = string
}

variable "public_ec2_role_name" {
  description = "IAM role name for the public-facing EC2 tier's instance profile"
  type        = string
  default     = null
}

variable "private_ec2_role_name" {
  description = "IAM role name for the private EC2 tier's instance profile"
  type        = string
  default     = null
}

variable "create_public_ec2" {
  description = "Whether to create the public-facing (front-end) EC2 Auto Scaling Group"
  type        = bool
  default     = false
}

variable "public_ec2_ami_id" {
  description = "Override AMI ID for the public tier; defaults to latest Amazon Linux 2023 if null"
  type        = string
  default     = null
}

variable "public_ec2_instance_type" {
  description = "EC2 instance type for the public tier"
  type        = string
  default     = "t3.micro"
}

variable "public_ec2_volume_size" {
  description = "Root EBS volume size (GB) for the public tier"
  type        = number
  default     = 20
}

variable "public_asg_min_size" {
  description = "Minimum number of instances in the public ASG"
  type        = number
  default     = 1
}

variable "public_asg_max_size" {
  description = "Maximum number of instances in the public ASG"
  type        = number
  default     = 2
}

variable "public_asg_desired_capacity" {
  description = "Desired number of instances in the public ASG"
  type        = number
  default     = 1
}

variable "create_private_ec2" {
  description = "Whether to create the private (back-end) EC2 Auto Scaling Group"
  type        = bool
  default     = false
}

variable "private_ec2_ami_id" {
  description = "Override AMI ID for the private tier; defaults to latest Amazon Linux 2023 if null"
  type        = string
  default     = null
}

variable "private_ec2_instance_type" {
  description = "EC2 instance type for the private tier"
  type        = string
  default     = "t3.micro"
}

variable "private_ec2_volume_size" {
  description = "Root EBS volume size (GB) for the private tier"
  type        = number
  default     = 20
}

variable "private_asg_min_size" {
  description = "Minimum number of instances in the private ASG"
  type        = number
  default     = 1
}

variable "private_asg_max_size" {
  description = "Maximum number of instances in the private ASG"
  type        = number
  default     = 2
}

variable "private_asg_desired_capacity" {
  description = "Desired number of instances in the private ASG"
  type        = number
  default     = 1
}

variable "target_cpu_utilization" {
  description = "Target average CPU utilization (%) for both ASGs' scaling policies"
  type        = number
  default     = 60
}

variable "create_ecs" {
  description = "Whether to create the ECS cluster and Fargate service"
  type        = bool
  default     = false
}

variable "ecs_task_cpu" {
  description = "CPU units for the ECS task definition"
  type        = string
  default     = "256"
}

variable "ecs_task_memory" {
  description = "Memory (MB) for the ECS task definition"
  type        = string
  default     = "512"
}

variable "container_image" {
  description = "Container image to run in the ECS task"
  type        = string
  default     = null
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 80
}

variable "ecs_desired_count" {
  description = "Desired number of running ECS tasks"
  type        = number
  default     = 1
}

variable "ecs_execution_role_arn" {
  description = "IAM role ARN ECS uses to pull images and write logs (from IAM module)"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "IAM role ARN the running container assumes (from IAM module)"
  type        = string
}

variable "ecs_launch_type" {
  description = "ECS launch type: 'FARGATE' or 'EC2'"
  type        = string
  default     = "FARGATE"

  validation {
    condition     = contains(["FARGATE", "EC2"], var.ecs_launch_type)
    error_message = "ecs_launch_type must be either 'FARGATE' or 'EC2'."
  }
}

variable "ecs_network_mode" {
  description = "Network mode for EC2-backed tasks ('awsvpc', 'bridge', or 'host'). Ignored for Fargate, which always uses awsvpc."
  type        = string
  default     = "bridge"
}

variable "ecs_container_cpu" {
  description = "Per-container CPU units (used for EC2-backed tasks; ignored for Fargate)"
  type        = number
  default     = null
}

variable "ecs_container_memory" {
  description = "Per-container hard memory limit in MB (used for EC2-backed tasks; ignored for Fargate)"
  type        = number
  default     = null
}

variable "ecs_container_memory_reservation" {
  description = "Per-container soft memory reservation in MB (used for EC2-backed tasks; ignored for Fargate)"
  type        = number
  default     = null
}