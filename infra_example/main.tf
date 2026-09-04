module "networking" {
  source = "../modules/networking"

  region           = var.region
  project_name     = var.project_name
  environment      = var.environment
  vpc_cidr         = var.vpc_cidr
  public_subnets   = var.public_subnets
  private_subnets  = var.private_subnets
  database_subnets = var.database_subnets
  ingress_rules    = var.ingress_rules
}

module "iam" {
  source = "../modules/iam"

  project_name              = var.project_name
  environment               = var.environment
  data_bucket_arn           = module.s3_bucket.bucket_arn
  athena_results_bucket_arn = "arn:aws:s3:::${lower(var.project_name)}-${var.environment}-athena-results-*"
  iam_group                 = var.iam_group
  iam_users                 = var.iam_users
}

module "s3_bucket" {
  source = "../modules/s3"

  project_name = var.project_name
  environment  = var.environment
  bucket_name  = var.bucket_name
}

module "data_platform_services" {
  source = "../modules/data_platform_services"

  project_name          = var.project_name
  environment           = var.environment
  data_bucket_name      = module.s3_bucket.bucket_id
  glue_crawler_role_arn = module.iam.glue_crawler_role_arn
}

module "rds" {
  source = "../modules/rds"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  database_subnet_ids   = module.networking.database_subnet_ids_list
  app_security_group_id = module.networking.security_group_id
  db_name               = var.db_name
  backup_retention_period  = var.backup_retention_period
}

module "compute" {
  source = "../modules/compute"

  project_name = var.project_name
  environment  = var.environment

  public_subnet_ids  = module.networking.public_subnet_ids_list
  private_subnet_ids = module.networking.private_subnet_ids_list

  public_security_group_id  = module.networking.public_security_group_id
  private_security_group_id = module.networking.security_group_id

  public_ec2_role_name  = module.iam.public_ec2_role_name
  private_ec2_role_name = module.iam.private_ec2_role_name

  create_public_ec2  = var.create_public_ec2
  create_private_ec2 = var.create_private_ec2

  create_ecs              = var.create_ecs
  ecs_launch_type          = var.ecs_launch_type
  container_image         = var.container_image
  ecs_execution_role_arn  = module.iam.ecs_execution_role_arn
  ecs_task_role_arn       = module.iam.ecs_task_role_arn
}