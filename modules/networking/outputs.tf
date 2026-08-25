output "region" {
  description = "The region of the account"
  value = var.region
}

output "project_name" {
  description = "The project name of the project. The default is COB"
  value = var.project_name
}

output "vpc_id" {
  description = "The id generated from the created VPC"
  value = aws_vpc.vpc.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.vpc.cidr_block
}






