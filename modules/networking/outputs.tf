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

output "public_subnet_ids_list" {
  description = "List of all public subnet IDs"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids_list" {
  description = "List of all private subnet IDs"
  value       = [for s in aws_subnet.private : s.id]
}

output "public_subnet_id_map" {
  description = "Map of public subnet name to subnet ID"
  value       = { for k, s in aws_subnet.public : k => s.id }
}

output "private_subnet_id_map" {
  description = "Map of private subnet name to subnet ID"
  value       = { for k, s in aws_subnet.private : k => s.id }
}

output "internet_gateway" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.internet_gateway.id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public_route_table.id
}


output "private_route_table_ids" {
  description = "Map of AZ/subnet key to private route table ID"
  value       = { for k, rt in aws_route_table.private_route_table : k => rt.id }
}

output "security_group_id" {
  description = "ID of the created security group"
  value       = aws_security_group.security_group.id
}

output "database_subnet_ids_list" {
  value = [for s in aws_subnet.database : s.id]
}

output "database_subnet_id_map" {
  description = "Map of database subnet name to subnet ID"
  value       = { for k, s in aws_subnet.database : k => s.id }
}

output "database_route_table_id" {
  description = "ID of the database route table"
  value       = aws_route_table.database_route_table.id
}

output "public_security_group_id" {
  value = aws_security_group.public_ec2_sg.id
}