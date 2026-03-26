# Container Definitions Reference

Full schema for the `container_definitions` input variable.

## Table of Contents

- [Schema Overview](#schema-overview)
- [Required Fields](#required-fields)
- [Resource Fields](#resource-fields)
- [Port Mappings](#port-mappings)
- [Health Check](#health-check)
- [Environment and Secrets](#environment-and-secrets)
- [Logging](#logging)
- [Lifecycle and Dependencies](#lifecycle-and-dependencies)
- [X-Ray Sidecar](#x-ray-sidecar)
- [ECR Pull-Through Cache](#ecr-pull-through-cache)
- [Complete Example](#complete-example)

## Schema Overview

```hcl
container_definitions = list(object({
  # Required
  name  = string
  image = string

  # ECR Pull-Through Cache
  pull_cache_prefix = optional(string, "")

  # Resources
  cpu                = optional(number)
  memory             = optional(number)
  memory_reservation = optional(number)

  # Lifecycle
  essential         = optional(bool, true)
  entrypoint        = optional(list(string))
  command           = optional(list(string))
  working_directory = optional(string)
  user              = optional(string)
  start_timeout     = optional(number)
  stop_timeout      = optional(number)

  # Networking
  port_mappings = optional(list(object({
    containerPort = number
    protocol      = optional(string, "tcp")
    name          = optional(string)
  })))

  # Health
  healthcheck = optional(object({
    command     = list(string)
    interval    = optional(number)
    retries     = optional(number)
    startPeriod = optional(number)
    timeout     = optional(number)
  }))

  # Environment
  environment = optional(list(object({
    name  = string
    value = string
  })))
  secrets = optional(list(object({
    name      = string
    valueFrom = string
  })))

  # Logging
  log_configuration = optional(object({
    logDriver = string
    options   = optional(map(string))
    secretOptions = optional(list(object({
      name      = string
      valueFrom = string
    })))
  }))

  # Dependencies
  depends_on = optional(list(object({
    condition     = string
    containerName = string
  })))

  # Limits
  ulimits = optional(list(object({
    hardLimit = number
    name      = string
    softLimit = number
  })))
}))
```

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | `string` | Container name. Referenced by `load_balancers[].container_name` and `service_registries.container_name` |
| `image` | `string` | Container image. Full URI for ECR, or public image like `nginx:latest` |

## Resource Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `cpu` | `number` | `null` | CPU units for the container. Sum of all containers must fit within `task_cpu` |
| `memory` | `number` | `null` | Hard memory limit in MiB. Container killed if exceeded |
| `memory_reservation` | `number` | `null` | Soft memory limit (memory reservation) in MiB |

## Port Mappings

```hcl
port_mappings = [
  {
    containerPort = 8080           # Required: port the container listens on
    protocol      = "tcp"          # Optional: "tcp" (default) or "udp"
    name          = "http"         # Optional: named port for Service Connect
  }
]
```

**Important:** The `name` field is required when using Service Connect. The `service_connect_configuration.port_name` must match one of these names. The module validates this at plan time.

## Health Check

```hcl
healthcheck = {
  command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
  interval    = 30    # Seconds between checks (default: 30)
  retries     = 3     # Failures before unhealthy (default: 3)
  startPeriod = 60    # Grace period for startup (default: 0)
  timeout     = 5     # Seconds per check attempt (default: 5)
}
```

Only `command` is required. Use `CMD-SHELL` prefix for shell commands, or `CMD` for direct execution.

## Environment and Secrets

### Plain Environment Variables

```hcl
environment = [
  { name = "APP_ENV",   value = "production" },
  { name = "LOG_LEVEL", value = "info" },
  { name = "PORT",      value = "8080" }
]
```

### Secrets (from Secrets Manager or SSM Parameter Store)

```hcl
secrets = [
  # From Secrets Manager
  { name = "DB_PASSWORD", valueFrom = "arn:aws:secretsmanager:eu-west-1:123456789:secret:db-password-AbCdEf" },

  # From Secrets Manager (specific JSON key)
  { name = "DB_HOST", valueFrom = "arn:aws:secretsmanager:eu-west-1:123456789:secret:db-config-AbCdEf:host::" },

  # From SSM Parameter Store
  { name = "API_KEY", valueFrom = "arn:aws:ssm:eu-west-1:123456789:parameter/api-key" }
]
```

The execution role must have permission to read these secrets. When using module-created roles, add policies via `module.my_service.service_execution_role_name`.

## Logging

### CloudWatch Logs (most common)

```hcl
log_configuration = {
  logDriver = "awslogs"
  options = {
    "awslogs-group"         = "/ecs/my-service"
    "awslogs-region"        = "eu-west-1"
    "awslogs-stream-prefix" = "app"
  }
}
```

### With Secret Options

```hcl
log_configuration = {
  logDriver = "splunk"
  options = {
    "splunk-url"    = "https://splunk.example.com"
    "splunk-source" = "ecs"
  }
  secretOptions = [
    { name = "splunk-token", valueFrom = "arn:aws:secretsmanager:..." }
  ]
}
```

## Lifecycle and Dependencies

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `essential` | `bool` | `true` | If `true`, task fails when this container exits |
| `entrypoint` | `list(string)` | `null` | Override image ENTRYPOINT |
| `command` | `list(string)` | `null` | Override image CMD |
| `working_directory` | `string` | `null` | Override working directory |
| `user` | `string` | `null` | Run as specific user (e.g. `"1000"`, `"root"`) |
| `start_timeout` | `number` | `null` | Seconds to wait for container to start |
| `stop_timeout` | `number` | `null` | Seconds to wait for container to stop gracefully |

### Container Dependencies

```hcl
depends_on = [
  { containerName = "init-db", condition = "SUCCESS" },
  { containerName = "sidecar", condition = "START" }
]
```

Valid conditions: `START`, `COMPLETE`, `SUCCESS`, `HEALTHY`.

### Ulimits

```hcl
ulimits = [
  { name = "nofile", softLimit = 65536, hardLimit = 65536 }
]
```

## X-Ray Sidecar

When `add_xray_container = true` (default), the module appends this container automatically:

| Property | Value |
|----------|-------|
| name | `xray-daemon` |
| image | `amazon/aws-xray-daemon:3.x` (configurable via `xray_container_image`) |
| cpu | 128 |
| memory | 256 |
| memory_reservation | 128 |
| port | 2000/UDP (named `xray`) |
| essential | true |
| stop_timeout | 30 |

The task role gets `AWSXRayDaemonWriteAccess` policy attached.

Set `add_xray_container = false` to disable and reclaim 128 CPU + 256 MiB memory.

## ECR Pull-Through Cache

Set `pull_cache_prefix` to use ECR pull-through cache rules:

```hcl
container_definitions = [{
  name              = "app"
  image             = "library/nginx:latest"
  pull_cache_prefix = "docker-hub"   # Matches an ECR pull-through cache rule prefix
}]
```

The module:
1. Looks up the ECR pull-through cache rule by prefix
2. Rewrites the image URL to `<ecr-registry>/<prefix>/<image>`
3. Adds IAM permissions for `ecr:CreateRepository` and `ecr:BatchImportUpstreamImage`
4. Adds permissions for any credential secrets and KMS keys used by the cache rule

## Complete Example

```hcl
container_definitions = [
  {
    name  = "app"
    image = "123456789.dkr.ecr.eu-west-1.amazonaws.com/my-app:1.2.3"

    cpu                = 256
    memory             = 512
    memory_reservation = 256

    port_mappings = [{
      containerPort = 8080
      protocol      = "tcp"
      name          = "http"
    }]

    healthcheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
      interval    = 30
      retries     = 3
      startPeriod = 60
      timeout     = 5
    }

    environment = [
      { name = "APP_ENV",   value = "production" },
      { name = "LOG_LEVEL", value = "info" }
    ]

    secrets = [
      { name = "DB_PASSWORD", valueFrom = "arn:aws:secretsmanager:eu-west-1:123456789:secret:db-pass-AbCdEf" }
    ]

    log_configuration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/my-app"
        "awslogs-region"        = "eu-west-1"
        "awslogs-stream-prefix" = "app"
      }
    }

    stop_timeout = 30
  },
  {
    name      = "init-db"
    image     = "123456789.dkr.ecr.eu-west-1.amazonaws.com/db-migrate:latest"
    essential = false
    command   = ["migrate", "--apply"]

    environment = [
      { name = "DB_HOST", value = "db.internal:5432" }
    ]

    secrets = [
      { name = "DB_PASSWORD", valueFrom = "arn:aws:secretsmanager:eu-west-1:123456789:secret:db-pass-AbCdEf" }
    ]

    log_configuration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/my-app"
        "awslogs-region"        = "eu-west-1"
        "awslogs-stream-prefix" = "init-db"
      }
    }
  }
]
```
