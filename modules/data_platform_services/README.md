# Data Platform Module

## Purpose

Provides reusable capability for exposing data stored in S3 to analytics
users, via AWS Glue Data Catalog (schema discovery/cataloging) and Amazon
Athena (serverless SQL querying).

## What It Creates

- `aws_glue_catalog_database` — the catalog namespace.

- `aws_glue_crawler` — scans a given S3 path and populates the catalog.

- `aws_s3_bucket` (Athena results) + versioning-independent lifecycle
  expiration + public access block.

- `aws_athena_workgroup` — enforced configuration, encrypted results.

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `project_name`, `environment` | `string` | cob | yes | Naming |
| `data_bucket_name` | `string` | — | yes | Name of the existing S3 bucket holding source data |
| `crawler_s3_prefix` | `string` | `""` | no | Prefix/folder within the bucket for the crawler to scan |
| `crawler_schedule` | `string` | `null` | no | Cron schedule; `null` = on-demand only |
| `glue_crawler_role_arn` | `string` | — | yes | IAM role ARN (from IAM module) |
| `query_results_retention_days` | `number` | `30` | no | Days before query result files expire |

## Outputs

| Name | Description |
|---|---|
| `glue_database_name` | Generated Glue Catalog database name |
| `glue_crawler_name` | Crawler name |
| `athena_results_bucket`, `athena_results_bucket_arn` | Results bucket identifiers |
| `athena_workgroup_name` | Workgroup name |

## Design Decisions & Trade-offs

- **Dedicated results bucket, separate from the source data bucket:**
  Query results are ephemeral and disposable (cheap to regenerate by
  re-running a query), while source data may carry longer-term retention
  needs. Separating them allows independent lifecycle policies (plain
  expiration for results vs. tiered version transitions for source data)
  and a cleaner IAM permission boundary (analysts get write access to
  results, read-only access to source data).

- **`enforce_workgroup_configuration = true`.** Without this, individual
  analysts could override the query output location or encryption
  settings per-query, silently defeating the bucket lockdown and
  encryption enforcement. This is the single most important line in the
  module from a governance standpoint.
- **Glue database name lowercased and hyphens replaced with underscores:**
  Glue Catalog database names disallow uppercase characters and hyphens —
  this is handled via `lower(replace(...))` rather than requiring
  consumers to pre-format `project_name`/`environment` correctly.

- **On-demand crawler schedule by default:** Avoids unnecessary crawler
  runs and cost for a dev/demo environment; a production deployment can
  override `crawler_schedule` with a cron expression for continuous
  freshness.

## What Breaks This Module

- **Uppercase characters surviving into the Glue database name:** The
  `replace()` call alone only swaps hyphens for underscores — it does
  nothing about uppercase letters in `project_name`/`environment`.
  This was sufficiently catered for by wrapping the full expression in the `lower()` function, as omitting it
  causes `apply` to fail with `invalid value for name (uppercase
  characters cannot be used)`.

- **Circular dependency if `athena_results_bucket_arn` is wired as a live
  module output into the IAM module:**, Since this module needs an IAM
  role ARN that only exists after the IAM module runs, this is resolved at the
  root level via a manually-constructed wildcard ARN pattern passed into
  IAM instead ([see IAM module README.md](../iam/README.md)).

## Limitations

- No support for multiple source buckets/crawlers per instantiation —
  one crawler, one target path, per module call.

- Crawler partition handling assumes a consistent schema across
  partitions (`InheritFromTable`) — highly irregular or evolving schemas
  across partitions may require manual catalog intervention.

## Example Usage

```hcl
module "data_platform_services" {
  source = "../modules/data_platform_services"

  project_name          = var.project_name
  environment           = var.environment
  data_bucket_name      = module.s3_bucket.bucket_id
  glue_crawler_role_arn = module.iam.glue_crawler_role_arn
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
```

### .tfvars

```hcl
project_name = "cob"
environment  = "dev"
```