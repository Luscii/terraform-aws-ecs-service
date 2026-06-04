module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"
  context = var.context
  name    = var.name
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ecs_cluster" "this" {
  cluster_name = var.ecs_cluster_name
}

// Logic checks for launch_type and capacity_provider_strategies

check "capacity_provider_strategies_force_new_deployment" {
  assert {
    condition     = length(var.capacity_provider_strategies) == 0 || var.force_new_deployment == true
    error_message = "If capacity_provider_strategies is set, force_new_deployment must be true."
  }
}

check "launch_type_capacity_provider_strategies_conflict" {
  assert {
    condition     = (var.launch_type == null && length(var.capacity_provider_strategies) > 0) || (var.launch_type != null && length(var.capacity_provider_strategies) == 0)
    error_message = "Either launch_type OR capacity_provider_strategies needs to be set. They cannot be set together."
  }
}
