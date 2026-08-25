# create vpc
resource "aws_vpc" "vpc" {
  region = var.region
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.resource_name}-vpc"
  }
}

# Internet gateway attached to the vpc
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.resource_name}-igw"
  }
}

# Get the available availability zones on the account
data "aws_availability_zones" "available_zones" {
  # get only the usable(available zones)
  state = "available"
  # filter for only availability-zone(omit local zones and wavelength zone)
  filter {
    name   = "zone_type"
    values = ["availability-zone"]
  }
}

# create public subnet
resource "aws_subnet" "public" {
    for_each = var.public_subnets

  vpc_id     = aws_vpc.vpc.id
  cidr_block = each.value.cidr_block
  availability_zone = coalesce(each.value.availability_zone, sort(data.aws_availability_zones.available.names)[index(keys(var.public_subnets), each.key)])

  tags = {
    Name = "${local.resource_name}-${each.key}"
  }
}

# Create Private Subnet
resource "aws_subnet" "private" {
    for_each = var.private_subnets

  vpc_id     = aws_vpc.vpc.id
  cidr_block = each.value.cidr_block
  availability_zone = coalesce(each.value.availability_zone, sort(data.aws_availability_zones.available.names)[index(keys(var.private_subnets), each.key)])

  tags = {
    Name = "${local.resource_name}-${each.key}"
  }
}

# create an elastic ip for nat gateway in each az
resource "aws_eip" "nat_eip" {
  for_each = aws_subnet.public
  domain   = "vpc"

  tags = {
    Name = "${local.resource_name}-${each.key}-nat-eip"
  }

  depends_on = [aws_internet_gateway.internet_gateway]
}

# create a nat gateway for each az for HA
resource "aws_nat_gateway" "nat_gateway" {
  for_each = aws_subnet.public
  allocation_id = aws_eip.nat_eip[each.key].id
  subnet_id     = each.value.id

  tags = {
    Name = "${local.resource_name}-${each.key}-nat-gw"
  }

  depends_on = [aws_internet_gateway.internet_gateway]
}

# create public route tables
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "${local.resource_name}-public-rt"
  }
}

# Associate public subnets to the public route table
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id
}

# create private route tables
resource "aws_route_table" "private_route_table" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway[each.key].id
  }

  tags = {
    Name = "${local.resource_name}-${each.key}-private-rt"
  }
}

# Associate private subnets to the private route table
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_route_table[each.key].id
}

resource "aws_security_group" "security_group" {
  name        = "${local.resource_name}-${var.name_suffix}"
  description = var.description
  vpc_id      = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description     = ingress.value.description
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      cidr_blocks     = length(ingress.value.cidr_blocks) > 0 ? ingress.value.cidr_blocks : null
      security_groups = length(ingress.value.security_groups) > 0 ? ingress.value.security_groups : null
    }
  }

  dynamic "egress" {
    for_each = var.egress_rules
    content {
      description     = egress.value.description
      from_port       = egress.value.from_port
      to_port         = egress.value.to_port
      protocol        = egress.value.protocol
      cidr_blocks     = length(egress.value.cidr_blocks) > 0 ? egress.value.cidr_blocks : null         # conditional checks to prevent cidr blocks from throwing errors when empty
      security_groups = length(egress.value.security_groups) > 0 ? egress.value.security_groups : null
    }
  }

  tags =  {
    Name = "${local.resource_name}-${var.name_suffix}"
  }
}







