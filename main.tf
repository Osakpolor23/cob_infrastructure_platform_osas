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