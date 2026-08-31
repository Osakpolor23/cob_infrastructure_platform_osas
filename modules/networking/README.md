# Networking Module

## Purpose

Provisions the foundational network layer for all other COB modules: a
VPC with three subnet tiers (public, private, database) spread across
multiple Availability Zones, routing, NAT for outbound access, Internet Gateway, and a
reusable security group.

## What It Creates

- `aws_vpc` — the VPC itself

- `aws_internet_gateway` — attached to the VPC. One Internet gateway is provided as only one point of entry is needed for outbound and inbound traffic, no matter the availability zone.

- `aws_subnet` (public, private, database) — one per AZ per tier, via `for_each` meta argument implementation.
- `aws_eip` + `aws_nat_gateway` — one NAT Gateway per AZ (high availability)

- `aws_route_table` (public — shared; private — one per AZ; database — shared, no NAT route)

- `aws_route_table_association` — for every subnet

- `aws_security_group` — reusable, with dynamic ingress/egress blocks
- `aws_security_group.public_ec2_sg` — separate SG for internet-facing EC2

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `project_name` | `string` | `"COB"` | no | Project name |
| `environment` | `string` | — | yes | Environment; validated against `dev/test/staging/prod` |
| `vpc_cidr` | `string` | — | yes | CIDR block for the VPC |
| `public_subnets` | `map(object)` | — | yes | Map of public subnets (`cidr_block`, optional `availability_zone`) |
| `private_subnets` | `map(object)` | — | yes | Map of private subnets |
| `database_subnets` | `map(object)` | — | yes | Map of database subnets |
| `ingress_rules` | `list(object)` | `[]` | no | Ingress rules for the shared security group |
| `egress_rules` | `list(object)` | allow-all | no | Egress rules for the shared security group |

## Outputs

| Name | Description |
|---|---|
| `vpc_id`, `vpc_cidr` | VPC identifiers |
| `public_subnet_ids_list`, `public_subnet_id_map` | Public subnet IDs |
| `private_subnet_ids_list`, `private_subnet_id_map` | Private subnet IDs |
| `database_subnet_ids_list` | Database subnet IDs |
| `internet_gateway` | IGW ID |
| `public_route_table_id` | Single shared public route table ID |
| `private_route_table_ids` | Map of AZ/subnet key → private route table ID |
| `security_group_id` | Shared internal security group ID |
| `public_security_group_id` | Internet-facing security group ID |

## Design Decisions & Trade-offs

- **Three subnet tiers instead of two.** A dedicated database subnet tier
  (rather than sharing the app tier's private subnets) was introduced
  specifically to support RDS: it requires no NAT route (databases don't
  need outbound internet access), giving tighter blast-radius separation
  between the app and data layers at the cost of additional subnet/route
  table resources to manage.
- **One NAT Gateway per AZ, not one shared NAT.** Ensures that if one AZ's
  NAT Gateway fails, only that AZ's private subnet loses outbound
  connectivity — not the whole environment. Trade-off: roughly doubles
  NAT Gateway cost compared to a single shared NAT.
- **AZ-based NAT-to-route-table matching, not name-based.** Private route
  tables look up their NAT Gateway by matching Availability Zone via a
  `local.nat_gateway_by_az` map, rather than assuming public/private
  subnet keys share naming conventions. This makes the module resilient
  to arbitrary subnet naming across consuming teams.
- **One shared security group for internal resources, one separate for
  public EC2.** Public-facing and internal traffic have fundamentally
  different trust boundaries and shouldn't share a rule set, even though
  it means slightly more resources to maintain.

## What Breaks This Module

- **AZ filter typo.** The `aws_availability_zones` data source filter
  must use `"zone-type"` (hyphenated) — `"zone_type"` (underscore) is
  rejected by the AWS API with `InvalidParameterValue`.
- **Fewer than 2 AZs available in region/account.** Multiple resources
  (`for_each` over subnet maps) assume at least 2 distinct AZs are usable;
  a region/account with only 1 available AZ will not satisfy RDS's
  subnet-group requirement downstream.
- **Referencing `private_route_table_id` as singular.** This resource
  uses `for_each`; consuming it as a single object (`.id` directly) will
  error. Use the map output (`private_route_table_ids`) with key lookup.

## Limitations

- No IPv6 support.
- No VPC endpoints (e.g. S3 Gateway Endpoint) — all S3 traffic from
  private/database subnets currently routes through NAT rather than
  privately within AWS's network, which is both a minor cost and latency
  inefficiency.
- Single VPC per module instantiation — no multi-VPC peering support.

## Example Usage

\```hcl
module "networking" {
  source = "../modules/networking"

  project_name = "COB"
  environment  = "dev"
  vpc_cidr     = "10.0.0.0/16"

  public_subnets = {
    "public-a" = { cidr_block = "10.0.0.0/24" }
    "public-b" = { cidr_block = "10.0.1.0/24" }
  }
  private_subnets = {
    "private-a" = { cidr_block = "10.0.10.0/24" }
    "private-b" = { cidr_block = "10.0.11.0/24" }
  }
  database_subnets = {
    "database-a" = { cidr_block = "10.0.20.0/24" }
    "database-b" = { cidr_block = "10.0.21.0/24" }
  }

  ingress_rules = [
    {
      description = "Allow HTTPS from anywhere"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}
```