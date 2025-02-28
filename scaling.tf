locals {
  scaling_enabled                 = var.scaling != null
  scheduled_scaling_enabled       = local.scaling_enabled && var.scaling_scheduled != null
  target_tracking_scaling_enabled = local.scaling_enabled && var.scaling_target != null
}

module "autoscaling_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  context    = module.label.context
  attributes = ["scaling"]
}

# ############## #
# Scaling Target #
# ############## #

resource "aws_appautoscaling_target" "this" {
  count = local.scaling_enabled ? 1 : 0

  resource_id        = "service/${data.aws_ecs_cluster.this.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  min_capacity = var.scaling.min_capacity
  max_capacity = var.scaling.max_capacity

  tags = module.autoscaling_label.tags
}

# ########################## #
# Scheduled Scaling Policies #
# ########################## #

module "autoscaling_scheduled_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  for_each   = local.scheduled_scaling_enabled ? var.scaling_scheduled : {}
  context    = module.autoscaling_label.context
  attributes = concat(module.autoscaling_label.attributes, ["scheduled", each.key])
}

resource "aws_appautoscaling_scheduled_action" "this" {
  for_each = local.scheduled_scaling_enabled ? var.scaling_scheduled : {}

  name = module.autoscaling_scheduled_label[each.key].id

  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  schedule = each.value.schedule
  timezone = each.value.timezone

  scalable_target_action {
    min_capacity = each.value.min_capacity
    max_capacity = each.value.max_capacity
  }
}

# ############################## #
# Target Tracking Scaling Policy #
# ############################## #

module "autoscaling_target_tracking_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  for_each   = local.target_tracking_scaling_enabled ? var.scaling_target : {}
  context    = module.autoscaling_label.context
  attributes = concat(module.autoscaling_label.attributes, [each.key])
}

resource "aws_appautoscaling_policy" "target" {
  for_each = local.scaling_enabled ? var.scaling_target : {}

  name               = module.autoscaling_target_tracking_label[each.key].id
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = each.value.predefined_metric_type
    }

    target_value       = each.value.target_value
    scale_in_cooldown  = each.value.scale_in_cooldown
    scale_out_cooldown = each.value.scale_out_cooldown
  }
}
