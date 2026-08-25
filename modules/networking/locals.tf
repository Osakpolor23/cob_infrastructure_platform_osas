locals {
    environment    = lower(var.environment) # normalizing the environment name e.g Prod,prod,PROD etc all becomes prod
    resource_name= "${var.project_name}-${local.environment}"
}