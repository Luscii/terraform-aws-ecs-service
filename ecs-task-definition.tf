locals {
  container_definitions_encoded = [for definition in module.container_definitions : definition.json_map_encoded]
  container_definitions_list    = "[${join(",", local.container_definitions_encoded)}]"

  required_envoy_cpu = var.service_connect_configuration != null ? (var.high_traffic_service ? 512 : 256) : 0
  required_envoy_mem = var.service_connect_configuration != null ? (var.high_traffic_service ? 128 : 64) : 0

  required_cpu    = sum([for definition in module.container_definitions : contains(keys(definition.json_map_object), "cpu") ? definition.json_map_object.cpu : 0]) + local.required_envoy_cpu
  required_memory = sum([for definition in module.container_definitions : contains(keys(definition.json_map_object), "memory") ? definition.json_map_object.memory : 0]) + local.required_envoy_mem
}

resource "aws_ecs_task_definition" "this" {
  family                = module.label.id
  container_definitions = local.container_definitions_list

  cpu    = var.task_cpu
  memory = var.task_memory

  task_role_arn      = var.task_role.arn
  execution_role_arn = var.execution_role.arn

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  tags = module.label.tags

  lifecycle {
    precondition {
      condition     = var.task_cpu >= local.required_cpu
      error_message = "task_cpu must be greater than the sum of CPU (${nonsensitive(local.required_cpu)}) for all containers in the task definition, including envoy (256 or 512)"
    }

    precondition {
      condition     = var.task_memory >= local.required_memory
      error_message = "value must be greater than the sum of Memory (${nonsensitive(local.required_memory)} Mb) for all containers in the task definition"
    }
    precondition {
      condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.task_cpu)
      error_message = "Task CPU must be one of 256, 512, 1024, 2048, 4096, 8192, 16384"
    }
    precondition {
      condition = (
        var.task_cpu == 256 && contains([512, 1024, 2048], var.task_memory) ||
        var.task_cpu == 512 && contains([1024, 2048, 4096], var.task_memory) ||
        var.task_cpu == 1024 && contains([2048, 3072, 4096, 5120, 6144, 7168, 8192], var.task_memory) ||
        var.task_cpu == 2048 && contains([4096, 5120, 6144, 7168, 8192, 9216, 10240, 11264, 12288, 13312, 14336, 15360, 16384], var.task_memory) ||
        var.task_cpu == 4096 && var.task_memory >= 8192 && var.task_memory <= 30720 && var.task_memory % 1024 == 0 ||
        var.task_cpu == 8192 && var.task_memory >= 16384 && var.task_memory <= 61440 && var.task_memory % 4096 == 0 ||
        var.task_cpu == 16384 && var.task_memory >= 32768 && var.task_memory <= 122880 && var.task_memory % 8192 == 0
      )
      error_message = "must be a valid combination of task_cpu and task_memory - https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-tasks-services.html#fargate-tasks-size"
    }
  }
}
