output "public_ec2_role_name" {
  description = "IAM role name for the public-facing EC2 tier"
  value       = aws_iam_role.public_ec2_role.name
}

output "private_ec2_role_name" {
  description = "IAM role name for the private EC2 tier"
  value       = aws_iam_role.private_ec2_role.name
}

output "ecs_execution_role_arn" {
  description = "The ARN of the ECS Task Execution Role name"
  value = aws_iam_role.ecs_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "The ARN of the ECS  Task Role name"
  value = aws_iam_role.ecs_task_role.arn
}

output "glue_crawler_role_arn" {
  description = "The ARN of the Crawler Role name"
  value = aws_iam_role.glue_crawler_role.arn
}

output "analysts_group_name" {
  description = "The Name of the generated Analysts Group"
  value = aws_iam_group.analysts.name
}
