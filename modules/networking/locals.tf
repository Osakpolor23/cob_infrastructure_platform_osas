locals {
    environment    = lower(var.environment) # normalizing the environment name e.g Prod,prod,PROD etc all becomes prod
    resource_name= "${var.project_name}-${local.environment}"

    nat_gateway_by_az = {
    for key, subnet in aws_subnet.public :
    subnet.availability_zone => aws_nat_gateway.nat_gateway[key].id
  }
}