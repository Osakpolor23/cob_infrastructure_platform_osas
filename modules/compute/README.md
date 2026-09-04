# Compute Module

## Purpose

Provisions application compute in two independently toggleable forms:
EC2 via Auto Scaling Group (public and/or private tier) for self-healing,
scalable virtual machines, and ECS on Fargate for containerized
workloads.

## What It Creates

- `aws_iam_instance_profile` — two independent profiles, one per EC2 tier
  (public and private), each wrapping its own IAM role.

- `aws_launch_template` + `aws_autoscaling_group` + `aws_autoscaling_policy`
  — one full set for the **public** tier, one full set for the
  **private** tier, each independently toggleable.

- `aws_ecs_cluster`, `aws_cloudwatch_log_group`, `aws_ecs_task_definition`,
  `aws_ecs_service` — supports both Fargate and EC2 launch types via
  `ecs_launch_type`.

## Inputs

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `project_name` | `string` | — | yes | Name of the project |
| `environment` | `string` | — | yes | Deployment environment (e.g. dev, test, staging, prod) |
| `public_subnet_ids` | `list(string)` | `[]` | no | Public subnet IDs — required if `create_public_ec2 = true` |
| `private_subnet_ids` | `list(string)` | — | yes | Private subnet IDs — used by the private EC2 tier and ECS |
| `public_security_group_id` | `string` | `null` | no | Security group ID for the public-facing EC2 tier — required if `create_public_ec2 = true` |
| `private_security_group_id` | `string` | — | yes | Security group ID for the private EC2 tier and ECS |
| `public_ec2_role_name` | `string` | `null` | no | IAM role name for the public tier's instance profile |
| `private_ec2_role_name` | `string` | `null` | no | IAM role name for the private tier's instance profile |
| `create_public_ec2` | `bool` | `false` | no | Whether to create the public-facing (front-end) EC2 Auto Scaling Group |
| `public_ec2_ami_id` | `string` | `null` | no | Override AMI ID for the public tier; defaults to latest Amazon Linux 2023 if null |
| `public_ec2_instance_type` | `string` | `"t3.micro"` | no | EC2 instance type for the public tier |
| `public_ec2_volume_size` | `number` | `20` | no | Root EBS volume size (GB) for the public tier |
| `public_asg_min_size` | `number` | `1` | no | Minimum number of instances in the public ASG |
| `public_asg_max_size` | `number` | `2` | no | Maximum number of instances in the public ASG |
| `public_asg_desired_capacity` | `number` | `1` | no | Desired number of instances in the public ASG |
| `create_private_ec2` | `bool` | `false` | no | Whether to create the private (back-end) EC2 Auto Scaling Group |
| `private_ec2_ami_id` | `string` | `null` | no | Override AMI ID for the private tier; defaults to latest Amazon Linux 2023 if null |
| `private_ec2_instance_type` | `string` | `"t3.micro"` | no | EC2 instance type for the private tier |
| `private_ec2_volume_size` | `number` | `20` | no | Root EBS volume size (GB) for the private tier |
| `private_asg_min_size` | `number` | `1` | no | Minimum number of instances in the private ASG |
| `private_asg_max_size` | `number` | `2` | no | Maximum number of instances in the private ASG |
| `private_asg_desired_capacity` | `number` | `1` | no | Desired number of instances in the private ASG |
| `target_cpu_utilization` | `number` | `60` | no | Target average CPU utilization (%) for both ASGs' scaling policies |
| `create_ecs` | `bool` | `false` | no | Whether to create the ECS cluster and service |
| `ecs_launch_type` | `string` | `"FARGATE"` | no | ECS launch type: `"FARGATE"` or `"EC2"` |
| `ecs_network_mode` | `string` | `"bridge"` | no | Network mode for EC2-backed tasks (`"awsvpc"`, `"bridge"`, or `"host"`); ignored for Fargate, which always uses `awsvpc` |
| `ecs_task_cpu` | `string` | `"256"` | no | Task-level CPU units; used only when `ecs_launch_type = "FARGATE"` |
| `ecs_task_memory` | `string` | `"512"` | no | Task-level memory (MB); used only when `ecs_launch_type = "FARGATE"` |
| `ecs_container_cpu` | `number` | `null` | no | Per-container CPU units; used only when `ecs_launch_type = "EC2"` |
| `ecs_container_memory` | `number` | `null` | no | Per-container hard memory limit (MB); used only when `ecs_launch_type = "EC2"` |
| `ecs_container_memory_reservation` | `number` | `null` | no | Per-container soft memory reservation (MB); used only when `ecs_launch_type = "EC2"` |
| `container_image` | `string` | `null` | no | Container image to run in the ECS task |
| `container_port` | `number` | `80` | no | Port the container listens on |
| `ecs_desired_count` | `number` | `1` | no | Desired number of running ECS tasks |
| `ecs_execution_role_arn` | `string` | — | yes | IAM role ARN ECS uses to pull images and write logs (from IAM module) |
| `ecs_task_role_arn` | `string` | — | yes | IAM role ARN the running container assumes (from IAM module) |

## Outputs

| Name | Description |
|---|---|
| `public_asg_name`, `private_asg_name` | ASG names, `null` if not created |
| `ecs_cluster_id`, `ecs_service_name` | ECS identifiers, `null` if not created |

## Design Decisions & Trade-offs

- **Two fully independent ASGs (public and private), not one toggle.**
  A single "which tier" flag would have forced an either/or choice; two
  independently toggleable ASGs let a consuming team run a public
  front-end fleet, a private back-end fleet, both, or neither, without
  restructuring the module.

- **Launch Template + ASG instead of a single `aws_instance`.** Enables
  genuine self-healing (unhealthy instances are replaced automatically)
  and elastic scaling (target-tracking CPU-based scaling policy), which a
  static `aws_instance` cannot provide.

- **No load balancer included.** Deliberately deferred — an ASG without a
  load balancer still provides self-healing, but elastic scaling isn't
  usable by live traffic without one. This was a scoped trade-off to keep
  the module's initial footprint manageable; see Limitations.

- **IMDSv2 enforced (`http_tokens = "required"`)** on all EC2 launch
  templates, closing a known SSRF-adjacent attack vector present with
  IMDSv1.

- **ECS unaffected by EC2 tier toggles.** Fargate already provides
  self-healing (failed tasks are restarted) and requires no EC2 host
  management, so it's modeled as a fully separate, independently
  toggleable concern from the EC2 tiers.

- **Independent IAM roles per EC2 tier:**
  An earlier version of this module used a single shared `ec2_role`,
  attached via a single shared instance profile, for both the public and
  private EC2 tiers. This meant both tiers were structurally forced to
  share identical permissions, with no way for a front-end fleet to have
  narrower access than a back-end fleet.

  This was resolved by splitting into two fully independent IAM roles:

  ```hcl
  resource "aws_iam_role" "public_ec2_role" { ... }
  resource "aws_iam_role" "private_ec2_role" { ... }
  ```

  Both roles share the same **trust policy** (EC2 is the trusted
  principal for both — they're both, after all, EC2 instances), but carry
  distinct **permissions**:

  - `public_ec2_role` — SSM Session Manager access only. The public
    (front-end) tier is assumed not to need direct AWS API access beyond
    being manageable.
  - `private_ec2_role` — SSM access plus read-only access to the project's
    S3 data bucket, reflecting that back-end workloads are more likely to
    need to read application data directly.

  **Why this design over a single shared role:** separating trust from
  permissions at the role level (rather than just at the instance-profile
  level) means the two tiers' permissions can diverge freely and
  immediately — adding a new permission to the private tier's role has no
  effect on the public tier, and vice versa. This is the same
  principle applied elsewhere in this project (e.g. the ECS
  execution-role/task-role split): infrastructure plumbing and
  actual workload permissions are kept on separate, independently
  adjustable identities.

  **Trade-off:** this doubles the number of EC2-related IAM roles and
  policy attachments compared to the original single-role design — more
  resources to reason about and maintain. Given this project's scale, that
  cost is small relative to the flexibility gained, and mirrors a pattern
  AWS itself recommends: separate roles per distinct workload tier, rather
  than one broad role reused everywhere.

- Launch-type-flexible ECS task definition

  The ECS task definition and service are parameterized by
  `ecs_launch_type` (`"FARGATE"` or `"EC2"`) rather than hardcoding
  Fargate compatibility. Fargate requires task-level `cpu`/`memory` and
  `awsvpc` networking; EC2-backed tasks commonly size resources per
  container instead and can use `bridge`, `host`, or `awsvpc` networking.
  The task definition and service conditionally adjust these fields based
  on the selected launch type.

## What Breaks This Module

- **`create_public_ec2 = true` without `public_subnet_ids` or
  `public_security_group_id` set.** Both default to empty/`null` and are
  only required conditionally — omitting them while enabling the public
  tier will fail at `apply`.

- **Flipping a `create_*` flag from `true` to `false` on an already-
  applied stack destroys the corresponding ASG and its running instances.**
  This is standard, correct Terraform behaviour, not a bug — but is worth
  deliberate caution given it results in real instance termination.

## Limitations

- No Application Load Balancer integration yet — see root [README's Future Improvements.](../../README.md#future-improvements)

- The AMI filter is pinned to the Amazon Linux 2023 naming pattern
  (`al2023-ami-*`). When AWS releases a successor generation, this
  filter will need to be updated manually — `most_recent = true` only
  selects the newest build *within* the pinned generation, not across
  generations.

- No `prevent_destroy` lifecycle protection currently applied to the
  ASGs — a deliberate simplification for this phase of the project;
  accidental flag-flip destroys are currently only guarded against by
  disciplined `terraform plan` review before `apply`.

- setting `ecs_launch_type = "EC2"` makes the task
definition and service EC2-compatible, but does **not** provision the
underlying EC2 container instances themselves (an ECS-optimized AMI
registered to the cluster, e.g. via a capacity provider or a dedicated
ASG). A cluster with no registered container instances cannot actually
run EC2-launch-type tasks — provisioning that registration is a planned
future addition, not currently part of this module.

## Example Usage

### main.tf

```hcl
module "compute" {
  source = "../modules/compute"

  project_name = "COB"
  environment  = "dev"

  public_subnet_ids  = module.networking.public_subnet_ids_list
  private_subnet_ids = module.networking.private_subnet_ids_list

  public_security_group_id  = module.networking.public_security_group_id
  private_security_group_id = module.networking.security_group_id

  public_ec2_role_name  = module.iam.public_ec2_role_name
  private_ec2_role_name = module.iam.private_ec2_role_name

  create_public_ec2  = true
  create_private_ec2 = true

  create_ecs              = true
  ecs_launch_type          = "FARGATE"
  container_image         = "public.ecr.aws/nginx/nginx:latest"
  ecs_execution_role_arn  = module.iam.ecs_execution_role_arn
  ecs_task_role_arn       = module.iam.ecs_task_role_arn
}
```

### variable.tf

```hcl
variable "container_image" {
  description = "Container image to run in the ECS task"
  type        = string
}

variable "create_public_ec2" {
  description = "Whether to create the public-facing (front-end) EC2 Auto Scaling Group"
  type        = bool
  default     = false
}

variable "create_private_ec2" {
  description = "Whether to create the private (back-end) EC2 Auto Scaling Group"
  type        = bool
  default     = false
}

variable "create_ecs" {
  description = "Whether to create the ECS cluster and service"
  type        = bool
  default     = false
}

variable "ecs_launch_type" {
  description = "ECS launch type: FARGATE or EC2"
  type        = string
  default     = "FARGATE"
}
```
### .tfvars

```hcl
container_image = "public.ecr.aws/nginx/nginx:latest"

create_public_ec2  = false
create_private_ec2 = false
create_ecs         = true

ecs_launch_type = "FARGATE"
```