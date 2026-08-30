module "networking" {
  source = "./modules/networking"

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
  source = "./modules/iam"

  project_name               = var.project_name
  environment                = var.environment
  data_bucket_arn            = module.s3_bucket.bucket_arn
  athena_results_bucket_arn  = "arn:aws:s3:::cob-dev-athena-results-placeholder"
  iam_group                  = var.iam_group
  iam_users                  = var.iam_users
}

module "s3_bucket" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment
  bucket_name  = var.bucket_name
}

