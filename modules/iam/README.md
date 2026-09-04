# IAM Module

## Purpose

Provides least-privilege IAM roles for AWS services (EC2, ECS, Glue) and
provisions IAM groups/users for human access, so that no other module or
consuming application requires long-lived access keys.

## What It Creates

- `aws_iam_role` — `public_ec2_role`, `private_ec2_role`,
  `ecs_execution_role`, `ecs_task_role`, `glue_crawler_role`.

- `aws_iam_role_policy_attachment` — AWS-managed policies (SSM for both
  EC2 roles, ECS task execution, Glue service).

- `aws_iam_role_policy` — custom inline policies scoping the private EC2
  role, ECS task role, and Glue crawler role to specific S3/Secrets
  access.

- `aws_iam_group` — `analysts`, with a policy scoping Athena/Glue/S3
  access.
- `aws_iam_user`, `aws_iam_user_group_membership`, `aws_iam_user_login_profile`

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `project_name` | `string` | `"COB"` | no | Project name |
| `environment` | `string` | — | yes | Environment |
| `data_bucket_arn` | `string` | — | yes | ARN of the S3 data bucket (used by the private EC2 role and ECS task role) |
| `athena_results_bucket_arn` | `string` | — | yes | ARN (or wildcard pattern) of the Athena results bucket |
| `iam_group` | `string` | — | yes | Name of the analysts group (prefixed automatically) |
| `iam_users` | `map(object)` | `{}` | no | Map of users → `groups` (list) and `console_access` (bool) |


## Outputs

| Name | Description |
|---|---|
| `public_ec2_role_name` | IAM role name for the public-facing EC2 tier (for instance profile use) |
| `private_ec2_role_name` | IAM role name for the private EC2 tier (for instance profile use) |
| `ecs_execution_role_arn`, `ecs_task_role_arn` | ECS role ARNs |
| `glue_crawler_role_arn` | Glue crawler role ARN |
| `analysts_group_name` | Generated analysts group name |

## Design Decisions & Trade-offs

- **Trust policy vs. permissions policy kept separate**, per standard IAM
  design — every role has its own `assume_role_policy` data source
  (who can assume it) distinct from its permissions attachments (what it
  can do once assumed).

- **Independent IAM roles per EC2 tier.** An earlier version of this
  module used a single shared `ec2_role` for both the public and private
  EC2 compute tiers, attached via a single shared instance profile. This
  meant both tiers were structurally forced to share identical
  permissions, with no way for a front-end fleet to have narrower access
  than a back-end fleet. This was resolved by splitting into two fully
  independent roles — `public_ec2_role` and `private_ec2_role` — that
  share the same **trust policy** (EC2 is the trusted principal for
  both) but carry distinct **permissions**:
  - `public_ec2_role` — SSM Session Manager access only. The public
    (front-end) tier is assumed not to need direct AWS API access beyond
    being manageable via Session Manager.
    
  - `private_ec2_role` — SSM access plus read-only access to the
    project's S3 data bucket, reflecting that back-end workloads are
    more likely to need to read application data directly.

  Separating trust from permissions at the role level (rather than just
  at the instance-profile level) means the two tiers' permissions can
  diverge freely and immediately — adding a new permission to the
  private tier's role has no effect on the public tier, and vice versa.
  This mirrors the ECS execution-role/task-role split described below:
  infrastructure plumbing and actual workload permissions are kept on
  separate, independently adjustable identities.

  **Trade-off:** this doubles the number of EC2-related IAM roles and
  policy attachments compared to the original single-role design — more
  resources to reason about and maintain. Given this project's scale,
  that cost is small relative to the flexibility gained, and mirrors a
  pattern AWS itself recommends: separate roles per distinct workload
  tier, rather than one broad role reused everywhere.

- **Execution role vs. task role split for ECS.** The execution role
  (ECS infrastructure: image pulls, log writes) and the task role
  (your application's own AWS API calls) are intentionally separate
  roles, so tightening application permissions never risks breaking
  container startup/logging.

- **Manually-constructed ARNs to break circular dependencies.** The IAM
  module needs to reference the RDS Secrets Manager secret and the
  data-platform Athena results bucket — both of which are created by
  modules that themselves depend on IAM roles this module creates. Rather
  than passing live module outputs (which would create an unresolvable
  cycle), ARNs are constructed by naming convention with wildcard suffixes

  (e.g. `${resource_name}-db-credentials-*`). Trade-off: this couples
  modules via an implicit naming contract that Terraform cannot enforce
  or validate — a typo in either module's naming would silently produce
  a non-matching ARN and a denied permission, not a plan-time error.

- **SSM over SSH for EC2 access.** The `AmazonSSMManagedInstanceCore`
  policy is attached to the EC2 role so instances can be managed via
  Session Manager, avoiding key-pair management and open SSH ports
  entirely. This is to avoid having the .pem key management issues and risks.

## What Breaks This Module

- **`resources` argument passed as a bare string instead of a list.**
  Every `resources` field in an `aws_iam_policy_document` statement must
  be a list, even for a single ARN — a bare string fails Terraform's
  type validation.

- **Mismatched naming convention between this module's wildcard ARN
  construction and the actual resource names created elsewhere** — if the
  RDS or data-platform module's secret/bucket naming changes, the IAM
  policies here will silently stop matching and access will be denied
  without an obvious error pointing back to this module.

## Limitations

- **Plaintext password exposure risk.** `aws_iam_user_login_profile`
  stores a generated password in Terraform state in plaintext unless a
  `pgp_key` is supplied per user. This module does not currently
  implement PGP encryption — anyone with state file read access can see
  initial console passwords. Flagged as a known limitation, not
  addressed in the current version due to setup overhead.

- **Group name references in `iam_users` require the exact generated
  group name** (e.g. `"cob-dev-analysts"`), not just a short label —
  brittle if naming conventions change.

- **Public and private EC2 roles both currently receive only a baseline
  permission set** (SSM only, or SSM plus S3 read) — as real application
  requirements emerge, these policies will need to be extended per role
  rather than assuming the current defaults are sufficient for
  production workloads.

## Example Usage

### main.tf
```hcl
module "iam" {
  source = "../modules/iam"

  project_name              = var.project_name
  environment               = var.environment
  data_bucket_arn           = module.s3_bucket.bucket_arn
  athena_results_bucket_arn = "arn:aws:s3:::${lower(var.project_name)}-${var.environment}-athena-results-*"
  iam_group                 = var.iam_group
  iam_users                 = var.iam_users
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

variable "iam_group" {
  description = "Name of the IAM group for analysts"
  type        = string
  default     = "analysts"
}

variable "iam_users" {
  description = "Map of IAM users to create and which groups/console access they get"
  type = map(object({
    groups         = list(string)
    console_access = bool
  }))
  default = {}
}
```

### .tfvars

```hcl
project_name = "cob"
environment  = "dev"
iam_group = "analysts"

iam_users = {
  "John-analyst" = {
    groups         = ["cob-dev-analysts"]
    console_access = true
  },
  "Richard-analyst" = {
    groups         = ["cob-dev-analysts"]
    console_access = true
  },
  "Jane-analyst" = {
    groups         = ["cob-dev-analysts"]
    console_access = true
  }
}
```