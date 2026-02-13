---
name: using-luscii-ecs-service
description: 'Integrates the Luscii terraform-aws-ecs-service module into Terraform configurations to deploy AWS ECS Fargate services. Use when asked to "create ECS service", "deploy Fargate service", "add ECS module", "configure service connect", "set up auto-scaling for ECS", "add container definitions", or working with Luscii ECS infrastructure as code.'
---

# Using the Luscii ECS Service Module

Integrates `terraform-aws-ecs-service` into Terraform configurations to deploy AWS ECS Fargate services following Luscii standards.

## When to Use

- Deploying a new ECS Fargate service
- Adding a containerized workload to an existing ECS cluster
- Configuring Service Connect, DNS discovery, or load balancer integration
- Setting up auto-scaling for an ECS service
- Referencing ECS service outputs (roles, security groups, discovery URLs)

## Quick Start

```terraform
module "my_service" {
  source = "github.com/Luscii/terraform-aws-ecs-service?ref=<version>"

  context = module.label.context
  name    = "my-service"

  ecs_cluster_name = "my-cluster"
  vpc_id           = var.vpc_id
  subnets          = var.private_subnet_ids
  task_cpu         = 512
  task_memory      = 1024

  container_definitions = [
    {
      name  = "app"
      image = "123456789.dkr.ecr.eu-west-1.amazonaws.com/my-app:latest"

      port_mappings = [{
        containerPort = 8080
        protocol      = "tcp"
        name          = "http"
      }]

      log_configuration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/my-service"
          "awslogs-region"        = "eu-west-1"
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ]

  egress_rules = [{
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }]
}
```

**Source:** Luscii modules are distributed via GitHub, NOT the Terraform Registry. Always use `github.com/Luscii/terraform-aws-ecs-service?ref=<version>`.

## Integration Workflow

Copy and track:

```
Progress:
- [ ] Step 1: Define service basics (name, cluster, networking)
- [ ] Step 2: Configure containers
- [ ] Step 3: Choose connectivity pattern
- [ ] Step 4: Configure security groups
- [ ] Step 5: Set up scaling (if needed)
- [ ] Step 6: Wire up outputs
- [ ] Step 7: Validate configuration
```

### Step 1: Define Service Basics

Every service requires these inputs:

```terraform
module "my_service" {
  source = "github.com/Luscii/terraform-aws-ecs-service?ref=<version>"

  context          = module.label.context  # CloudPosse label context
  name             = "api"                 # Service name
  ecs_cluster_name = "production"          # Existing ECS cluster
  vpc_id           = var.vpc_id
  subnets          = var.private_subnet_ids
  task_cpu         = 512                   # CPU units
  task_memory      = 1024                  # Memory in MiB
  # ...
}
```

For valid CPU/memory combinations, see [references/inputs.md](references/inputs.md#valid-cpumemory-combinations).

### Step 2: Configure Containers

Define at least one container. Full schema at [references/container-definitions.md](references/container-definitions.md).

Key points:
- An **X-Ray sidecar** is added by default (128 CPU, 256 MiB). Set `add_xray_container = false` to disable.
- `task_cpu`/`task_memory` must fit all containers + Envoy sidecar (if Service Connect is used: +256 CPU / +64 MiB, or +512 CPU / +128 MiB for `high_traffic_service = true`).
- **Port names** matter: `port_mappings[].name` is referenced by `service_connect_configuration.port_name` and validated at plan time.
- The module auto-creates task and execution IAM roles unless you provide `task_role` and `execution_role`.

### Step 3: Choose Connectivity Pattern

Pick one (or combine):

**A) Service Connect only** (ECS-to-ECS via service mesh):
```terraform
  service_connect_configuration = {
    namespace  = "production"
    port_name  = "http"              # Must match a port_mappings name
    client_alias = {
      dns_name = "api"               # Other ECS services connect to api:8080
      port     = 8080
    }
  }
```

**B) Load Balancer** (public or internal ALB/NLB):
```terraform
  load_balancers = [{
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"         # Must match a container name
    container_port   = 8080          # Must match a container port
  }]
```

**C) Hybrid** (Service Connect + DNS for non-ECS clients):
```terraform
  service_connect_configuration = { /* ... */ }
  service_discovery_dns_namespace_ids = [
    aws_service_discovery_private_dns_namespace.internal.id
  ]
```

**D) Manual service registry** (full control over Cloud Map):
```terraform
  service_registries = {
    registry_arn   = aws_service_discovery_service.custom.arn
    container_name = "app"
    container_port = 8080
  }
```

Options C and D can be combined. Details at [references/inputs.md](references/inputs.md#service-discovery--connectivity).

### Step 4: Configure Security Groups

The module creates a security group with self-referencing ingress. Add rules:

```terraform
  ingress_rules = [{
    description     = "Allow HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [module.alb.security_group_id]
  }]

  egress_rules = [{
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }]

  security_group_ids = [aws_security_group.shared.id]  # Additional SGs
```

### Step 5: Set Up Scaling (If Needed)

First enable scaling, then add policies. See [references/scaling.md](references/scaling.md).

```terraform
  scaling = { min_capacity = 2, max_capacity = 10 }

  scaling_target = {
    cpu = {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
      target_value           = 70
    }
  }
```

**Note:** `desired_count` is ignored after initial creation (lifecycle ignore). Scaling manages task count.

### Step 6: Wire Up Outputs

Common output usage patterns. Full reference at [references/outputs.md](references/outputs.md).

```terraform
# Attach IAM policy to the task role
resource "aws_iam_role_policy_attachment" "custom" {
  role       = module.my_service.service_task_role_name
  policy_arn = aws_iam_policy.custom.arn
}

# Reference internal URL in another service's env vars
environment = [{
  name  = "API_URL"
  value = module.my_service.service_discovery_internal_url  # "http://api:8080"
}]

# Pass label context to child modules
module "service_secrets" {
  source  = "github.com/Luscii/terraform-aws-service-secrets?ref=<version>"
  context = module.my_service.label_context
}

# Use security group for cross-service access
resource "aws_security_group_rule" "allow" {
  source_security_group_id = module.my_service.security_group_id
  # ...
}

# Build on scaling target for custom policies
resource "aws_appautoscaling_policy" "custom" {
  count              = module.my_service.scaling_target != null ? 1 : 0
  resource_id        = module.my_service.scaling_target.resource_id
  scalable_dimension = module.my_service.scaling_target.scalable_dimension
  service_namespace  = module.my_service.scaling_target.service_namespace
  # ...
}
```

### Step 7: Validate Configuration

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan
```

Common validation errors:
- **"Task CPU must be one of..."** — invalid `task_cpu` value
- **"must be a valid combination of task_cpu and task_memory"** — see [CPU/memory table](references/inputs.md#valid-cpumemory-combinations)
- **"task_cpu must be greater than the sum of CPU..."** — containers + Envoy exceed `task_cpu`
- **"Port name must be one of the container port names"** — `service_connect_configuration.port_name` doesn't match any `port_mappings[].name`
- **"Load Balancer container name must be one of the container names"** — `load_balancers[].container_name` doesn't match any container

## Key Behaviors

1. **desired_count ignored after creation** — lifecycle ignore; use scaling or AWS Console
2. **Circuit breaker always enabled** — failed deployments auto-rollback; 50% min healthy, 400% max
3. **X-Ray sidecar by default** — 128 CPU + 256 MiB; set `add_xray_container = false` to disable
4. **Self-referencing security group** — all containers in the service can communicate
5. **Auto-created IAM roles** — unless `task_role`/`execution_role` provided; policies attached either way
6. **ECR pull-through cache auto-detected** — set `pull_cache_prefix` on containers to use

## Requirements

- Terraform >= 1.3
- AWS Provider >= 6.0
- Existing ECS cluster and VPC with subnets

## Reference

- **[references/inputs.md](references/inputs.md)** — All variables, types, defaults, and constraints
- **[references/outputs.md](references/outputs.md)** — All outputs with types, value expressions, and usage
- **[references/container-definitions.md](references/container-definitions.md)** — Full container definition schema
- **[references/scaling.md](references/scaling.md)** — Auto-scaling configuration details
