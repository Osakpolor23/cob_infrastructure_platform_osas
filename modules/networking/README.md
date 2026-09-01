# Networking Module

## Purpose

Provisions the foundational network layer for all other COB modules: a
VPC with three subnet tiers (public, private, database) spread across
multiple Availability Zones, routing, NAT for outbound access from the private subnet, Internet Gateway, and
reusable security groups.

## What It Creates

- `aws_vpc` — the VPC itself.

- `aws_internet_gateway` — attached to the VPC. The module provides one Internet gateway, as only one point of entry is needed for outbound and inbound traffic, no matter the availability zone.

- `aws_subnet` (public, private, database) — one per AZ per tier, via `for_each` meta argument implementation. The module makes the provision of a third tier isolated or database subnets for hosting databases - which doesn't require internet connectivity.

- `aws_eip` + `aws_nat_gateway` — One NAT Gateway per AZ (high availability). 

- `aws_route_table` : public — shared; private — one per AZ; database — shared, no NAT route. The public subnets in all AZs uses a single route table that routes network to the internet gateway (The end goal of all the public subnets is the internet).

- `aws_route_table_association` — A route table asscociation to associate each route table to its subnet using the `for_each` meta argument.

- `aws_security_group` — reusable, with dynamic ingress/egress blocks.

- `aws_security_group.public_ec2_sg` — separate SG for internet-facing EC2.

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `project_name` | `string` | `"cob"` | no | Project name |
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

- **Three subnet tiers instead of two:** A dedicated database subnet tier
  (rather than sharing the app tier's private subnets) was introduced
  specifically to support RDS: it requires no NAT route (databases don't
  need outbound internet access), giving tighter blast-radius separation
  between the app and data layers at the cost of additional subnet/route
  table resources to manage.

- **One NAT Gateway per AZ, not one shared NAT:** This design was opted for instead of having one shared NAT gateway across multiple AZs. Even though that approach saves cost, but it will be at the expense of having the risk of a single-point-of-failure, where the unavailability or failure of the NAT gateway will result in the inability of the other private subnets in other AZs to route network to that NAT gateway and connect to the internet even though they are healthy and in good conditions.

  It ensures that if one AZ's NAT Gateway fails, only that AZ's private subnet loses outbound connectivity and not the whole environment.

  **Trade-off:** Roughly doubles
  NAT Gateway cost compared to a single shared NAT.

- **AZ-based NAT-to-route-table matching, not name-based:** Private route
  tables look up their NAT Gateway by matching Availability Zone via a
  `local.nat_gateway_by_az` map, rather than assuming public/private
  subnet keys share naming conventions. This makes the module resilient
  to arbitrary subnet naming across consuming teams.

  **For more context:**

  An earlier version of this module linked each private subnet's route
  table to its NAT Gateway using `aws_nat_gateway.nat_gateway[each.key]` —
  directly reusing the private subnet's own key as the lookup key into the
  NAT Gateway map. This failed with:

  ```
  Error: Invalid index
  aws_nat_gateway.nat_gateway is object with 2 attributes
  each.key is "private-b"
  The given key does not identify an element in this collection value.
  ```

  **Why it failed**

  NAT Gateways in this module are created with `for_each = aws_subnet.public`. So, the NAT Gateway map is keyed on **public** subnet names (e.g.
  `"public-a"`, `"public-b"`). The private route table, however, iterates
  with `for_each = aws_subnet.private`, so inside that block `each.key` is a
  **private** subnet name (e.g. `"private-b"`). The original code assumed
  these two naming schemes would always line up i.e that a private subnet
  named `"private-b"` would have a corresponding NAT Gateway map entry also
  named `"private-b"`. That entry never exists, because the NAT Gateway map
  was never keyed on private subnet names in the first place. This is not a
  typo — it's an implicit, undocumented naming assumption that breaks the
  moment a consuming team names their public and private subnets
  differently (e.g. `"pub-east"` and `"backend-1"`).

  **The fix**

  The actual relationship that matters is not "same subnet name". Instead, it's
  "same Availability Zone." A private subnet's outbound traffic must route
  through whichever NAT Gateway physically resides in that subnet's AZ,
  regardless of what either subnet happens to be called. The fix builds an
  intermediate lookup map, keyed by AZ instead of by subnet name:

  ```hcl
  locals {
    nat_gateway_by_az = {
      for key, subnet in aws_subnet.public :
      subnet.availability_zone => aws_nat_gateway.nat_gateway[key].id
    }
  }
  ```

  This produces a map like:

  ```hcl
  {
    "us-east-1a" = "nat-0fd90f3788446c54d"
    "us-east-1b" = "nat-0c7488f2203245f90"
  }
  ```

  The private route table then looks up its NAT Gateway by the private
  subnet's own AZ, not by name:

  ```hcl
  resource "aws_route_table" "private_route_table" {
    for_each = aws_subnet.private

    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = local.nat_gateway_by_az[each.value.availability_zone]
    }
  }
  ```

  **Why this matters for module consumers**

  Because the lookup is now AZ-based rather than name-based, this module
  places **no naming requirements or conventions** on how you key your
  public and private subnet maps. A public subnet named `"pub-east"` in
  `us-east-1a` and a private subnet named `"app-backend"` in `us-east-1a`
  will correctly resolve to the same NAT Gateway, purely because they share
  an Availability Zone — with no coordination or naming discipline required
  between the two maps.

  **The one constraint this introduces**

  This lookup assumes **exactly one public subnet per Availability Zone**.
  If two public subnets were ever created in the same AZ, the
  `nat_gateway_by_az` map would silently retain only one of them (a map
  cannot have two entries with the same key — the later one in iteration
  order wins), and any private subnet in that AZ would still resolve
  correctly to *a* NAT Gateway, just not necessarily a specific one you
  might have intended. This module's expected usage pattern — one public
  subnet per AZ makes this a non-issue in practice, but it's worth
  stating explicitly for anyone extending the module.

- **One shared security group for internal resources, one separate for
  public EC2:** Public-facing and internal traffic have fundamentally
  different trust boundaries and shouldn't share a rule set, even though
  it means slightly more resources to maintain.

## What Breaks This Module
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

### main.tf

```hcl
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
```

### variable.tf

```hcl
variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "cob"
}

variable "environment" {
  description = "The environment of the project e.g dev, test, staging, prod"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block of the VPC"
  type        = string
}

variable "public_subnets" {
  description = "Map of public subnets to create"
  type = map(object({
    cidr_block        = string
    availability_zone = optional(string)
  }))
}

variable "private_subnets" {
  description = "Map of private subnets to create"
  type = map(object({
    cidr_block        = string
    availability_zone = optional(string)
  }))
}

variable "database_subnets" {
  description = "Map of database subnets to create"
  type = map(object({
    cidr_block        = string
    availability_zone = optional(string)
  }))
}

variable "ingress_rules" {
  description = "Ingress rules for the security group"
  type = list(object({
    description     = string
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string), [])
    security_groups = optional(list(string), [])
  }))
  default = []
}
```

### .tfvars

```hcl
project_name = "cob"
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
```
