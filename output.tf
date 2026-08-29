output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.networking.public_subnet_ids_list
}

output "public_subnet_id_map" {
  description = "Map of public subnet name to subnet ID"
  value       = module.networking.public_subnet_id_map
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.networking.private_subnet_ids_list
}

output "private_subnet_id_map" {
  description = "Map of private subnet name to subnet ID"
  value       = module.networking.private_subnet_id_map
}

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = module.networking.database_subnet_ids_list
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.networking.internet_gateway
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = module.networking.public_route_table_id
}

output "private_route_table_ids" {
  description = "Map of AZ/subnet key to private route table ID"
  value       = module.networking.private_route_table_ids
}

output "database_route_table_id" {
  description = "ID of the database route table"
  value       = module.networking.database_route_table_id
}

output "database_subnet_id_map" {
  description = "Map of database subnet name to subnet ID"
  value       = module.networking.database_subnet_id_map
}

output "security_group_id" {
  description = "ID of the security group created by the networking module"
  value       = module.networking.security_group_id
}

output "s3_bucket_id" {
  description = "ID (name) of the S3 bucket"
  value       = module.s3_bucket.bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.s3_bucket.bucket_arn
}