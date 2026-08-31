# S3 Module

## Purpose

Provisions a secure-by-default S3 bucket for general-purpose data storage,
intended to back other COB modules (e.g. as the source bucket for the
data_platform module's Glue crawler).

## What It Creates

- `aws_s3_bucket` — the bucket itself, with a globally-unique name built
  from `project_name`, `environment`, `bucket_name`, and a random suffix

- `aws_s3_bucket_versioning` - enabled

- `aws_s3_bucket_public_access_block` - all four public-access flags set
  to block/ignore

- `aws_s3_bucket_ownership_controls` - BucketOwnerEnforced

- `aws_s3_bucket_lifecycle_configuration` - noncurrent version transitions
  (Standard-IA at 30 days, Glacier at 60 days) and expiration at 90 days

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `project_name` | `string` | cob | yes | Project name, used in naming convention |
| `environment` | `string` | — | yes | Environment (`dev`/`test`/`staging`/`prod`) |
| `bucket_name` | `string` | — | yes | Base name for the bucket |

## Outputs

| Name | Description |
|---|---|
| `bucket_id` | The bucket's name/ID |
| `bucket_arn` | The bucket's ARN |

## Design Decisions & Trade-offs

- **Random suffix on bucket name:** S3 bucket names are globally unique
  across all AWS accounts, not just this one. A random 6-character suffix
  avoids naming collisions without requiring manual coordination between
  teams deploying this module independently. Trade-off: bucket names are
  not fully predictable ahead of `apply`, so any external system needing
  to reference this bucket by name must consume the `bucket_id` output
  rather than assuming a fixed name.

- **`BucketOwnerEnforced` over ACLs:** disables object ACLs entirely in
  favour of IAM/bucket-policy-based access control, aligned with AWS's
  current best-practice guidance. Trade-off: any legacy tooling relying on
  object-level ACLs will not work against this bucket.

- **Lifecycle tiering rather than flat expiration:** noncurrent versions
  transition through cheaper storage classes before eventual deletion,
  rather than being deleted outright at a fixed age. This preserves
  recovery capability for a window while reducing storage cost, at the
  cost of added configuration complexity relative to a single expiration
  rule.

## What Breaks This Module

- **Uppercase or invalid characters in `project_name`/`bucket_name`.** S3
  bucket names must be all lowercase. This module wraps the final bucket
  name in `lower()` to guard against this.

- **Global name collision**: In the extremely unlikely event the random
  suffix collides with an existing bucket name elsewhere in AWS (not
  scoped to this account) — re-running `apply` will generate a new
  suffix and resolve this.

## Limitations

- No server-side encryption configuration is currently applied by
  default (relies on S3's default encryption behavior) — a customer-managed
  KMS key option is a reasonable future addition for stricter environments.

- No cross-region replication support.

## Example Usage

### main.tf

```hcl
module "s3_bucket" {
  source = "../modules/s3"

  project_name = "COB"
  environment  = "dev"
  bucket_name  = "app-data"
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

variable "bucket_name" {
  description = "Base name for the S3 bucket (will be prefixed with project-environment and suffixed with a six-digit random string for uniqueness)"
  type        = string
}
```


## .tfvars

```hcl
project_name = "cob"
environment  = "dev"
bucket_name = "s3-bucket"
```
