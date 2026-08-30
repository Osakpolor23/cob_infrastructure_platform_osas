output "public_asg_name" {
  description = "Name of the public-facing (front-end) EC2 Auto Scaling Group, if created"
  value       = var.create_public_ec2 ? aws_autoscaling_group.public_asg[0].name : null
}

output "private_asg_name" {
  description = "Name of the private (back-end) EC2 Auto Scaling Group, if created"
  value       = var.create_private_ec2 ? aws_autoscaling_group.private_asg[0].name : null
}

output "ecs_cluster_id" {
  description = "ID of the ECS cluster, if created"
  value       = var.create_ecs ? aws_ecs_cluster.cluster[0].id : null
}

output "ecs_service_name" {
  description = "Name of the ECS Fargate service, if created"
  value       = var.create_ecs ? aws_ecs_service.service[0].name : null
}