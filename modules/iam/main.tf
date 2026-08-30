data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Generates an ec2 IAM trust policy document in JSON format for use by ec2_role
data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# create the ec2_role trust policy by attaching to the generated JSON
resource "aws_iam_role" "ec2_role" {
  name               = "${local.resource_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
}

# Create the ec2 policy that allows it to be managed by AWS Systems Manager (SSM) Session Manager instead of .pem keys
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"   # enables Session Manager — no SSH keys needed
}

# Generates an ecs IAM trust policy document in JSON format for use by ecs_task_execution_role
data "aws_iam_policy_document" "ecs_tasks_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# create a ecs-task-execution-role by attaching by assuming the role
resource "aws_iam_role" "ecs_execution_role" {
  name               = "${local.resource_name}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role_policy.json
}


# Attach the task-execution role to the AWS Managed TaskExecutionRole Policy
resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Create a Task role by assuming the same trust policy json
resource "aws_iam_role" "ecs_task_role" {
  name               = "${local.resource_name}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role_policy.json
}

# create in-line ecs task policies
data "aws_iam_policy_document" "ecs_task_permissions" {
  statement {
    sid       = "ReadDataBucket"
    actions   = ["s3:GetObject", "s3:ListBucket",
                  "s3:GetObjectTagging"]
    resources = [var.data_bucket_arn, "${var.data_bucket_arn}/*"]
  }
  statement {
    sid       = "ReadDbSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${local.resource_name}-db-credentials-*"]
  }
}

# Attach task role to the created in-line policies 
resource "aws_iam_role_policy" "ecs_task_policy" {
  name   = "${local.resource_name}-ecs-task-policy"
  role   = aws_iam_role.ecs_task_role.id
  policy = data.aws_iam_policy_document.ecs_task_permissions.json
}


# Generates an amzon glue IAM trust policy document in JSON format for use by glue-crawler role
data "aws_iam_policy_document" "glue_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

# create the glue-crawler role by attaching to the generated JSON
resource "aws_iam_role" "glue_crawler_role" {
  name               = "${local.resource_name}-glue-crawler-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume_role_policy.json
}

# Attach the glue-crawler role to the AWS Managed AWSGlueServiceRole Policy
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# generate the json for the glue-crawler s3 bucket read
data "aws_iam_policy_document" "glue_s3_read" {
  statement {
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [var.data_bucket_arn, "${var.data_bucket_arn}/*"]
  }
}

# Ceate the glue-crawler3 read role by attaching the generated JSON
resource "aws_iam_role_policy" "glue_s3_read_policy" {
  name   = "${local.resource_name}-glue-s3-read"
  role   = aws_iam_role.glue_crawler_role.id
  policy = data.aws_iam_policy_document.glue_s3_read.json
}

# Create an IAM group called analysts
resource "aws_iam_group" "analysts" {
  name = "${local.resource_name}-${var.iam_group}"
}

# Generate the JSON policy for the Analysts group
data "aws_iam_policy_document" "analyst_permissions" {
  statement {
    sid = "AthenaQuery"
    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:StopQueryExecution",
      "athena:GetWorkGroup"
    ]
    resources = ["*"]
  }
  statement {
    sid       = "GlueCatalogRead"
    actions   = ["glue:GetDatabase", "glue:GetTable", "glue:GetTables", "glue:GetPartitions"]
    resources = ["*"]
  }
  statement {
    sid       = "AthenaResultsBucket"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
    resources = [var.athena_results_bucket_arn, "${var.athena_results_bucket_arn}/*"]
  }
  statement {
    sid       = "ReadOnlyDataBucket"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [var.data_bucket_arn, "${var.data_bucket_arn}/*"]
  }
}

# Create the Analyst group policy
resource "aws_iam_group_policy" "analyst_policy" {
  name   = "${local.resource_name}-${var.iam_group}-policy"
  group  = aws_iam_group.analysts.name
  policy = data.aws_iam_policy_document.analyst_permissions.json
}

# Create IAM Users
resource "aws_iam_user" "users" {
  for_each = var.iam_users

  name = each.key
  tags = {
    Name = each.key
  }
}

#  Attach Users to the Analysts Group
resource "aws_iam_user_group_membership" "user_groups" {
  for_each = var.iam_users
  user     = aws_iam_user.users[each.key].name
  groups   = each.value.groups
}

# Enable Console Access and Request Password change on first login
resource "aws_iam_user_login_profile" "console_access" {
  for_each                = { for k, v in var.iam_users : k => v if v.console_access }
  user                    = aws_iam_user.users[each.key].name
  password_reset_required = true
}