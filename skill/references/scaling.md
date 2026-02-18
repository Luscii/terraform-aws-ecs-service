# Scaling Reference

Auto-scaling configuration for ECS services. Covers target tracking, scheduled scaling, and custom policies.

## Table of Contents

- [Enable Scaling](#enable-scaling)
- [Target Tracking Policies](#target-tracking-policies)
- [Scheduled Scaling](#scheduled-scaling)
- [Custom Scaling Policies via Output](#custom-scaling-policies-via-output)
- [Examples](#examples)

## Enable Scaling

**Required before any scaling policy.** The `scaling` variable creates an `aws_appautoscaling_target`:

```hcl
scaling = {
  min_capacity = 2    # Minimum running tasks
  max_capacity = 10   # Maximum running tasks
}
```

Without this, `scaling_target` and `scaling_scheduled` are ignored.

**Note:** `desired_count` is ignored after initial creation (lifecycle ignore). The scaling target controls task count.

## Target Tracking Policies

The `scaling_target` variable creates `aws_appautoscaling_policy` resources with target tracking:

```hcl
scaling_target = {
  "<policy_name>" = {
    predefined_metric_type = string             # Required
    resource_label         = optional(string)    # Required for ALBRequestCountPerTarget
    target_value           = number              # Required
    scale_in_cooldown      = optional(number, 300)   # Seconds
    scale_out_cooldown     = optional(number, 300)   # Seconds
  }
}
```

### Predefined Metrics

| Metric | Description | resource_label |
|--------|-------------|----------------|
| `ECSServiceAverageCPUUtilization` | Average CPU % across tasks | Not needed |
| `ECSServiceAverageMemoryUtilization` | Average memory % across tasks | Not needed |
| `ALBRequestCountPerTarget` | Requests per target from ALB | **Required** (see format below) |

### ALB Resource Label Format

When using `ALBRequestCountPerTarget`, `resource_label` must follow:

```
app/<alb-name>/<alb-id>/targetgroup/<tg-name>/<tg-id>
```

Example:
```hcl
scaling_target = {
  requests = {
    predefined_metric_type = "ALBRequestCountPerTarget"
    resource_label         = "app/my-alb/50dc6c495c0c9188/targetgroup/my-tg/6d482bd40d5df576"
    target_value           = 1000
  }
}
```

You can construct this from ALB and target group outputs:
```hcl
resource_label = "${module.alb.arn_suffix}/${aws_lb_target_group.app.arn_suffix}"
```

### Cooldown Periods

| Parameter | Default | Description |
|-----------|---------|-------------|
| `scale_in_cooldown` | 300 | Seconds to wait after scale-in before another scale-in |
| `scale_out_cooldown` | 300 | Seconds to wait after scale-out before another scale-out |

Lower values = more responsive. Higher values = more stable.

## Scheduled Scaling

The `scaling_scheduled` variable creates `aws_appautoscaling_scheduled_action` resources:

```hcl
scaling_scheduled = {
  "<policy_name>" = {
    schedule     = string   # Cron or rate expression
    timezone     = string   # IANA timezone
    min_capacity = number   # Min tasks during this schedule
    max_capacity = number   # Max tasks during this schedule
  }
}
```

### Schedule Expressions

```hcl
# Cron: cron(minutes hours day-of-month month day-of-week year)
schedule = "cron(0 7 * * ? *)"     # Every day at 07:00
schedule = "cron(0 7 ? * MON *)"   # Every Monday at 07:00
schedule = "cron(30 8 1 * ? *)"    # 1st of each month at 08:30

# Rate:
schedule = "rate(5 minutes)"
schedule = "rate(1 hour)"
```

### Timezone

Use IANA timezone identifiers:

```hcl
timezone = "Europe/Amsterdam"
timezone = "UTC"
timezone = "America/New_York"
```

## Custom Scaling Policies via Output

The `scaling_target` output (the resource, not the variable) exposes the `aws_appautoscaling_target` for creating custom policies outside the module:

```hcl
resource "aws_appautoscaling_policy" "custom" {
  count = module.my_service.scaling_target != null ? 1 : 0

  name               = "custom-step-policy"
  policy_type        = "StepScaling"
  resource_id        = module.my_service.scaling_target.resource_id
  scalable_dimension = module.my_service.scaling_target.scalable_dimension
  service_namespace  = module.my_service.scaling_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      scaling_adjustment          = 2
      metric_interval_lower_bound = 0
    }
  }
}
```

The output object contains:
- `resource_id` — `"service/<cluster>/<service>"`
- `scalable_dimension` — `"ecs:service:DesiredCount"`
- `service_namespace` — `"ecs"`
- `min_capacity`, `max_capacity`

## Examples

### CPU-Based Scaling

```hcl
module "api" {
  source = "github.com/Luscii/terraform-aws-ecs-service?ref=<version>"
  # ...

  scaling = {
    min_capacity = 2
    max_capacity = 20
  }

  scaling_target = {
    cpu = {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
      target_value           = 70
    }
  }
}
```

### Multi-Metric Scaling

```hcl
  scaling = {
    min_capacity = 2
    max_capacity = 20
  }

  scaling_target = {
    cpu = {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
      target_value           = 70
      scale_in_cooldown      = 300
      scale_out_cooldown     = 60
    }
    memory = {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
      target_value           = 80
    }
  }
```

### Business Hours Scaling

```hcl
  scaling = {
    min_capacity = 1
    max_capacity = 20
  }

  scaling_scheduled = {
    weekday_morning = {
      schedule     = "cron(0 7 ? * MON-FRI *)"
      timezone     = "Europe/Amsterdam"
      min_capacity = 4
      max_capacity = 20
    }
    weekday_evening = {
      schedule     = "cron(0 20 ? * MON-FRI *)"
      timezone     = "Europe/Amsterdam"
      min_capacity = 1
      max_capacity = 5
    }
    weekend = {
      schedule     = "cron(0 0 ? * SAT *)"
      timezone     = "Europe/Amsterdam"
      min_capacity = 1
      max_capacity = 3
    }
  }

  scaling_target = {
    cpu = {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
      target_value           = 70
    }
  }
```

### ALB Request Count Scaling

```hcl
  scaling = {
    min_capacity = 2
    max_capacity = 50
  }

  scaling_target = {
    requests = {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${module.alb.arn_suffix}/${aws_lb_target_group.app.arn_suffix}"
      target_value           = 1000
      scale_out_cooldown     = 60
    }
  }
```
