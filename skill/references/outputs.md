# Outputs Reference

All outputs from the `terraform-aws-ecs-service` module, with types, value expressions, and usage patterns.

## Table of Contents

- [String Outputs](#string-outputs)
- [Complex Outputs](#complex-outputs)
- [Common Output Usage Patterns](#common-output-usage-patterns)

## String Outputs

### Cluster

| Output | Type | Value Expression | Description |
|--------|------|-----------------|-------------|
| `cluster_name` | `string` | `data.aws_ecs_cluster.this.cluster_name` | Name of the ECS cluster |
| `cluster_arn` | `string` | `data.aws_ecs_cluster.this.arn` | ARN of the ECS cluster |

### Task Definition

| Output | Type | Value Expression | Description |
|--------|------|-----------------|-------------|
| `task_definition_id` | `string` | `aws_ecs_task_definition.this.id` | ID of the task definition |
| `task_definition_arn` | `string` | `aws_ecs_task_definition.this.arn` | ARN (includes revision, e.g. `arn:...:task-definition/name:3`) |
| `task_definition_family` | `string` | `aws_ecs_task_definition.this.family` | Family name (without revision) |

### Service

| Output | Type | Value Expression | Description |
|--------|------|-----------------|-------------|
| `service_id` | `string` | `aws_ecs_service.this.id` | ID of the service |
| `service_name` | `string` | `aws_ecs_service.this.name` | Name of the service |
| `service_arn` | `string` | `aws_ecs_service.this.id` | ARN of the service (value is the resource ID) |

### IAM Roles

These return the module-created role or the user-provided role, whichever applies.

| Output | Type | Value Expression | Description |
|--------|------|-----------------|-------------|
| `service_task_role_arn` | `string` | `try(aws_iam_role.task[0].arn, var.task_role.arn)` | Task role ARN |
| `service_task_role_name` | `string` | `try(aws_iam_role.task[0].name, var.task_role.name)` | Task role name (= ID) |
| `service_task_role_id` | `string` | `try(aws_iam_role.task[0].id, var.task_role.name)` | Task role ID (= name) |
| `service_execution_role_arn` | `string` | `try(aws_iam_role.execution[0].arn, var.execution_role.arn)` | Execution role ARN |
| `service_execution_role_name` | `string` | `try(aws_iam_role.execution[0].name, var.execution_role.name)` | Execution role name (= ID) |
| `service_execution_role_id` | `string` | `try(aws_iam_role.execution[0].id, var.execution_role.name)` | Execution role ID (= name) |

### Security Group

| Output | Type | Value Expression | Description |
|--------|------|-----------------|-------------|
| `security_group_id` | `string` | `aws_security_group.this.id` | Security group ID |
| `security_group_arn` | `string` | `aws_security_group.this.arn` | Security group ARN |

### Service Discovery

| Output | Type | Value Expression | Description |
|--------|------|-----------------|-------------|
| `service_discovery_name` | `string` or `null` | `try(aws_ecs_service.this.service_connect_configuration[0].service[0].discovery_name, null)` | Discovery name. `null` if no Service Connect |
| `service_discovery_internal_url` | `string` or `null` | `try("http://${...dns_name}:${...port}", null)` | Internal URL like `http://api:8080`. `null` if no Service Connect |

## Complex Outputs

### `label_context`

**Type:** CloudPosse label context object

**Value:** `module.label.context`

Full CloudPosse label context for passing to child modules or sibling services. Contains: `namespace`, `tenant`, `environment`, `stage`, `name`, `delimiter`, `attributes`, `tags`, `additional_tag_map`, `label_order`, `id_length_limit`, `label_key_case`, `label_value_case`, `labels_as_tags`, `descriptor_formats`, `enabled`, `regex_replace_chars`.

```terraform
# Pass to child module
module "service_secrets" {
  source  = "github.com/Luscii/terraform-aws-service-secrets?ref=<version>"
  context = module.my_service.label_context
}
```

### `service_discovery_client_aliases`

**Type:** `list(list(object({dns_name=string, port=number})))` or `null`

**Value:** `try(aws_ecs_service.this.service_connect_configuration[0].service[*].client_alias, null)`

Returns `null` when Service Connect is not configured. When set, it's a list of lists (one per service block, each containing its client aliases):

```
[
  [
    { dns_name = "api", port = 8080 }
  ]
]
```

Access:
```terraform
locals {
  alias_dns  = try(module.my_service.service_discovery_client_aliases[0][0].dns_name, null)
  alias_port = try(module.my_service.service_discovery_client_aliases[0][0].port, null)
}
```

### `scaling_target`

**Type:** `aws_appautoscaling_target` resource object or `null`

**Value:** `local.scaling_enabled ? aws_appautoscaling_target.this[0] : null`

Returns `null` when `scaling` is not configured. When set, contains the full resource attributes:

```
{
  id                 = "..."
  resource_id        = "service/cluster-name/service-name"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  min_capacity       = 2
  max_capacity       = 10
  role_arn           = "arn:aws:iam::..."
  tags               = { ... }
  tags_all           = { ... }
}
```

Use for adding custom scaling policies outside the module:
```terraform
resource "aws_appautoscaling_policy" "custom" {
  count = module.my_service.scaling_target != null ? 1 : 0

  name               = "custom-policy"
  resource_id        = module.my_service.scaling_target.resource_id
  scalable_dimension = module.my_service.scaling_target.scalable_dimension
  service_namespace  = module.my_service.scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    # ...
  }
}
```

## Common Output Usage Patterns

### Attach IAM Policies to Task Role

```terraform
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = module.my_service.service_task_role_name
  policy_arn = aws_iam_policy.s3_access.arn
}

resource "aws_iam_role_policy" "inline" {
  name   = "custom-policy"
  role   = module.my_service.service_task_role_name
  policy = data.aws_iam_policy_document.custom.json
}
```

### Attach IAM Policies to Execution Role

```terraform
resource "aws_iam_role_policy_attachment" "secrets" {
  role       = module.my_service.service_execution_role_name
  policy_arn = aws_iam_policy.secrets_access.arn
}
```

### Cross-Service Security Group Access

```terraform
resource "aws_security_group_rule" "allow_from_api" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = module.api_service.security_group_id
  security_group_id        = aws_security_group.database.id
}
```

### Reference Internal URL in Another Service

```terraform
module "worker_service" {
  source = "github.com/Luscii/terraform-aws-ecs-service?ref=<version>"
  # ...
  container_definitions = [{
    name  = "worker"
    image = "worker:latest"
    environment = [{
      name  = "API_BASE_URL"
      value = module.api_service.service_discovery_internal_url  # "http://api:8080"
    }]
    # ...
  }]
}
```

### Conditional Logic Based on Scaling

```terraform
# Add CloudWatch alarms only when scaling is enabled
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = module.my_service.scaling_target != null ? 1 : 0
  # ...
}
```
