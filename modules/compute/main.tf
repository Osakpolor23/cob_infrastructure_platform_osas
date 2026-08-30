data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_region" "current" {}

resource "aws_iam_instance_profile" "ec2_profile" {
  count = (var.create_public_ec2 || var.create_private_ec2) ? 1 : 0
  name  = "${local.resource_name}-ec2-profile"
  role  = var.ec2_role_name
}

resource "aws_launch_template" "public_app_server" {
  count         = var.create_public_ec2 ? 1 : 0
  name_prefix   = "${local.resource_name}-public-lt-"
  image_id      = coalesce(var.public_ec2_ami_id, data.aws_ami.amazon_linux.id)
  instance_type = var.public_ec2_instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile[0].name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.public_security_group_id]
  }

  metadata_options {
    http_tokens = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.public_ec2_volume_size
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.resource_name}-public-app-server" }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "public_asg" {
  count               = var.create_public_ec2 ? 1 : 0
  name                = "${local.resource_name}-public-asg"
  vpc_zone_identifier = var.public_subnet_ids

  min_size         = var.public_asg_min_size
  max_size         = var.public_asg_max_size
  desired_capacity = var.public_asg_desired_capacity

  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.public_app_server[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.resource_name}-public-app-server"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "public_scale_out" {
  count                   = var.create_public_ec2 ? 1 : 0
  name                    = "${local.resource_name}-public-scale-out"
  autoscaling_group_name  = aws_autoscaling_group.public_asg[0].name
  policy_type             = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.target_cpu_utilization
  }
}

resource "aws_launch_template" "private_app_server" {
  count         = var.create_private_ec2 ? 1 : 0
  name_prefix   = "${local.resource_name}-private-lt-"
  image_id      = coalesce(var.private_ec2_ami_id, data.aws_ami.amazon_linux.id)
  instance_type = var.private_ec2_instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile[0].name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.private_security_group_id]
  }

  metadata_options {
    http_tokens = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.private_ec2_volume_size
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.resource_name}-private-app-server" }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "private_asg" {
  count               = var.create_private_ec2 ? 1 : 0
  name                = "${local.resource_name}-private-asg"
  vpc_zone_identifier = var.private_subnet_ids

  min_size         = var.private_asg_min_size
  max_size         = var.private_asg_max_size
  desired_capacity = var.private_asg_desired_capacity

  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.private_app_server[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.resource_name}-private-app-server"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "private_scale_out" {
  count                   = var.create_private_ec2 ? 1 : 0
  name                    = "${local.resource_name}-private-scale-out"
  autoscaling_group_name  = aws_autoscaling_group.private_asg[0].name
  policy_type             = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.target_cpu_utilization
  }
}

resource "aws_ecs_cluster" "cluster" {
  count = var.create_ecs ? 1 : 0
  name  = "${local.resource_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  count             = var.create_ecs ? 1 : 0
  name              = "/ecs/${local.resource_name}"
  retention_in_days = 30
}

resource "aws_ecs_task_definition" "task" {
  count                    = var.create_ecs ? 1 : 0
  family                   = "${local.resource_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-container"
      image     = var.container_image
      essential = true
      portMappings = [{ containerPort = var.container_port, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs[0].name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "service" {
  count           = var.create_ecs ? 1 : 0
  name            = "${local.resource_name}-service"
  cluster         = aws_ecs_cluster.cluster[0].id
  task_definition = aws_ecs_task_definition.task[0].arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.private_security_group_id]
    assign_public_ip = false
  }
}