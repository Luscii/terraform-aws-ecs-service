# Inputs Reference

All input variables for the `terraform-aws-ecs-service` module.

## Table of Contents

- [Required Inputs](#required-inputs)
- [Valid CPU/Memory Combinations](#valid-cpumemory-combinations)
- [Context and Naming](#context-and-naming)
- [IAM Roles](#iam-roles)
- [Container Configuration](#container-configuration)
- [Service Discovery / Connectivity](#service-discovery--connectivity)
- [Security Groups](#security-groups)
- [Load Balancers](#load-balancers)
- [Scaling](#scaling)
- [Deployment and Miscellaneous](#deployment-and-miscellaneous)

## Required Inputs

| Variable | Type | Description |
|----------|------|-------------|
| `name` | `string` | Name of the ECS service |
| `ecs_cluster_name` | `string` | Name of the existing ECS cluster |
| `vpc_id` | `string` | ID of the VPC |
| `subnets` | `list(string)` | Subnet IDs where tasks run |
| `task_cpu` | `number` | CPU units: 256, 512, 1024, 2048, 4096, 8192, or 16384 |
| `task_memory` | `number` | Memory in MiB (must be valid combination with `task_cpu`) |
| `container_definitions` | `list(object)` | Container definitions (see [container-definitions.md](container-definitions.md)) |

## Valid CPU/Memory Combinations

Fargate enforces specific CPU/memory pairs. The module validates at plan time.

| task_cpu | Valid task_memory (MiB) |
|----------|------------------------|
| 256 | 512, 1024, 2048 |
| 512 | 1024, 2048, 4096 |
| 1024 | 2048, 3072, 4096, 5120, 6144, 7168, 8192 |
| 2048 | 4096 through 16384 (in 1024 increments) |
| 4096 | 8192 through 30720 (in 1024 increments) |
| 8192 | 16384 through 61440 (in 4096 increments) |
| 16384 | 32768 through 122880 (in 8192 increments) |

### Resource Budget

`task_cpu` and `task_memory` must accommodate all containers plus sidecars:

| Component | CPU | Memory |
|-----------|-----|--------|
| Your containers | Sum of all container `cpu` | Sum of all container `memory` |
| X-Ray sidecar (default on) | 128 | 256 MiB |
| Envoy (Service Connect, normal) | 256 | 64 MiB |
| Envoy (Service Connect, high traffic) | 512 | 128 MiB |

The module validates that `task_cpu >= sum(container CPU) + envoy CPU` and `task_memory >= sum(container memory) + envoy memory`.

## Context and Naming

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `context` | `any` | CloudPosse defaults | CloudPosse label context for consistent naming/tagging. Pass from parent module: `context = module.label.context` |

The `context` object supports: `namespace`, `tenant`, `environment`, `stage`, `name`, `delimiter`, `attributes`, `tags`, `additional_tag_map`, `label_order`, `id_length_limit`, `label_key_case`, `label_value_case`, `labels_as_tags`.

## IAM Roles

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `task_role` | `object({name=string, arn=string})` | `null` | Existing task role. `null` = module creates one |
| `execution_role` | `object({name=string, arn=string})` | `null` | Existing execution role. `null` = module creates one |
| `enable_ecs_execute_command` | `bool` | `false` | Enable ECS Exec (attaches SSM policy to task role) |

When providing your own roles, the module still attaches policies by role name:
- **Execution role**: `AmazonElasticContainerRegistryPublicReadOnly`, `AmazonECSTaskExecutionRolePolicy`, ECR pull-through cache policy (if used)
- **Task role**: `AWSXRayDaemonWriteAccess` (if X-Ray enabled), ECS Exec policy (if enabled)

## Container Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `container_definitions` | `list(object)` | *required* | Container definitions. See [container-definitions.md](container-definitions.md) |
| `add_xray_container` | `bool` | `true` | Add X-Ray daemon sidecar (128 CPU, 256 MiB, port 2000/UDP) |
| `xray_container_image` | `string` | `"amazon/aws-xray-daemon:3.x"` | X-Ray daemon image |

## Service Discovery / Connectivity

### Service Connect (ECS-to-ECS)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `service_connect_configuration` | `object` | `null` | Service Connect configuration |

```hcl
service_connect_configuration = {
  namespace      = optional(string)   # Service Connect namespace
  discovery_name = optional(string)   # Discovery name
  port_name      = optional(string)   # Must match a container port_mappings[].name
  client_alias   = optional(object({
    dns_name = string                 # DNS name other services use
    port     = number                 # Port other services use
  }))
  cloudwatch = optional(object({      # Envoy proxy logging
    log_group = string
    region    = string
  }))
}
```

### DNS-Based Discovery (for non-ECS clients)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `service_discovery_dns_namespace_ids` | `list(string)` | `[]` | Cloud Map private DNS namespace IDs. Module auto-creates services using `client_alias.dns_name` as service name. Requires `service_connect_configuration` |
| `service_registries` | `object` | `null` | Manual Cloud Map registry configuration |

```hcl
service_registries = {
  registry_arn   = string             # Cloud Map service ARN
  container_name = optional(string)   # For SRV records
  container_port = optional(number)   # For SRV records
}
```

Both `service_discovery_dns_namespace_ids` and `service_registries` can be used simultaneously.

### High Traffic

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `high_traffic_service` | `bool` | `false` | >500 req/s: allocates 512 CPU + 128 MiB for Envoy (instead of 256 + 64) |

## Security Groups

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ingress_rules` | `list(object)` | `[]` | Additional ingress rules |
| `egress_rules` | `list(object)` | `[]` | Egress rules |
| `security_group_ids` | `list(string)` | `[]` | Additional security group IDs to attach |

Rule object structure:

```hcl
{
  description      = string            # Required
  from_port        = number            # Required
  to_port          = number            # Required
  protocol         = optional(string, "-1")  # "-1" = all
  cidr_blocks      = optional(list(string))
  ipv6_cidr_blocks = optional(list(string))
  prefix_list_ids  = optional(list(string))
  security_groups  = optional(list(string))
  self             = optional(bool)
}
```

The module always creates one self-referencing ingress rule (all traffic within the security group).

## Load Balancers

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `load_balancers` | `list(object)` | `[]` | ALB/NLB target group attachments |

```hcl
load_balancers = [{
  target_group_arn = string   # Target group ARN
  container_name   = string   # Must match a container name (validated)
  container_port   = number   # Must match a container port (validated)
}]
```

## Scaling

See [scaling.md](scaling.md) for detailed configuration.

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `scaling` | `object({min_capacity=number, max_capacity=number})` | `null` | Enable scaling. Required for any scaling policy |
| `scaling_target` | `map(object)` | `null` | Target tracking scaling policies |
| `scaling_scheduled` | `map(object)` | `null` | Scheduled scaling policies |

## Deployment and Miscellaneous

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `desired_count` | `number` | `1` | Initial task count. **Ignored after creation** (lifecycle ignore) |
| `assign_public_ip` | `bool` | `false` | Assign public IP to tasks |
| `platform_version` | `string` | `"LATEST"` | Fargate platform version |
| `force_new_deployment` | `bool` | `false` | Force new deployment on apply |
| `app_version` | `string` | `null` | Added as `AppVersion` tag on task definition |
