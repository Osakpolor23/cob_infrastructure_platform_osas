# RDS Module

## Purpose

Provisions a PostgreSQL RDS instance deployed into isolated database
subnets, with generated credentials stored securely in the AWS Secrets Manager,
and networking/security scoped to accept connections only from the
application tier.

## What It Creates

- `random_password` — generates the master password

- `aws_secretsmanager_secret` + `aws_secretsmanager_secret_version` — stores full connection details as JSON

- `aws_db_subnet_group` — spans the provided database subnets

- `aws_security_group` — allows inbound 5432 only from the app security group

- `aws_db_parameter_group` — PostgreSQL 16 family, connection logging enabled

- `aws_db_instance` — the actual RDS instance

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `project_name` | `string` | cob | yes | Project name |
| `environment` | `string` | — | yes | Environment |
| `vpc_id` | `string` | — | yes | VPC ID (from networking module) |
| `database_subnet_ids` | `list(string)` | — | yes | Database subnet IDs (from networking module) |
| `app_security_group_id` | `string` | — | yes | Security group allowed to reach the DB |
| `db_name` | `string` | `"appdb_instance"` | no | PostgreSQL database name (no hyphens — underscores only) |
| `master_username` | `string` | `"postgres_admin"` | no | Master username |
| `engine_version` | `string` | `"16.4"` | no | PostgreSQL engine version |
| `parameter_group_family` | `string` | `"postgres16"` | no | Parameter group family |
| `instance_class` | `string` | `"db.t3.micro"` | no | Instance class |
| `storage_type` | `string` | `"gp3"` | no | EBS storage type |
| `allocated_storage` | `number` | `20` | no | Initial storage (GB) |
| `max_allocated_storage` | `number` | `3000` | no | Storage autoscaling ceiling (GB) |
| `multi_az` | `bool` | `false` | no | Enable Multi-AZ failover |
| `deletion_protection` | `bool` | `true` | no | Prevent accidental deletion |
| `skip_final_snapshot` | `bool` | `false` | no | Skip snapshot on deletion |
| `backup_retention_period` | `number` | `1`* | no | Days of automated backups |
| `backup_window`, `maintenance_window` | `string` | preset | no | Scheduled maintenance windows |
| `performance_insights_enabled` | `bool` | `false` | no | Enable Performance Insights |

*Lowered from a typical production default of 7 to remain deployable on AWS Free Tier accounts.

## Outputs

| Name | Description |
|---|---|
| `db_instance_endpoint` | Connection endpoint (sensitive) |
| `db_instance_id` | RDS instance identifier |
| `db_secret_arn` | Secrets Manager ARN holding full credentials |
| `rds_security_group_id` | Security group ID |

## Design Decisions & Trade-offs

- **Credentials never hardcoded — generated and stored in Secrets Manager:**
  The master password is generated via `random_password` and immediately
  written to a Secrets Manager secret alongside host/port/dbname, so
  consuming applications fetch one JSON blob at runtime via IAM role
  permissions rather than any password ever appearing in `.tfvars`,
  environment variables, or a container image.

- **Security-group-to-security-group ingress, not CIDR-based:** The RDS
  security group allows inbound 5432 from the app tier's *security group*
  rather than an IP range, so it scales automatically as app instances
  are added, removed, or replaced.

- **No dedicated app-level database user.** The application currently
  connects using the master/admin credentials fetched from Secrets
  Manager. A more mature setup would provision a separate, narrower-
  permissioned application user post-creation.
- **`deletion_protection = true` by default:** Prevents accidental
  destruction via `terraform destroy` or console action. Trade-off: full
  stack teardown requires manually disabling this flag and re-applying
  before destroy will succeed — an intentional friction point, not a bug.

## What Breaks This Module

- **Hyphens in `db_name`:** PostgreSQL database identifiers cannot
  contain hyphens — only letters, numbers, and underscores. A hyphenated
  `db_name` will cause `apply` to fail at instance creation.

- **Mismatch between the actual `db_name` and the value written into the
  Secrets Manager secret's `dbname` field:** If these two ever diverge
  (e.g. a leftover random suffix applied to one but not the other), the
  secret will point applications at a database name that doesn't exist —
  this fails silently at `apply` time and only surfaces when an
  application actually tries to connect.

- **`backup_retention_period` exceeding Free Tier limits:** AWS Free Tier
  accounts reject `CreateDBInstance` if backup retention exceeds the
  account's tier limit — this module's default was lowered specifically
  to remain deployable in that scenario.

- **Fewer than 2 AZs represented in `database_subnet_ids`:** RDS requires
  a subnet group spanning at least 2 distinct Availability Zones.

## Limitations

- No read replica support currently.
- No automated app-level (non-master) database user provisioning.
- `multi_az = false` by default — no automatic failover unless explicitly
  enabled, which roughly doubles RDS cost.

## Example Usage

### main.tf
```hcl
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

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "appdb_instance"
}

variable "backup_retention_period" {
  description = "Number of days to retain automated RDS backups"
  type        = number
  default     = 1
}
```


### .tfvars

```hcl
project_name = "cob"
environment  = "dev"
db_name = "appdb_instance"
backup_retention_period = 1
```