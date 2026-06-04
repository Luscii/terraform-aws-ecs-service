locals {
  container_definitions_encoded = [for definition in module.container_definitions : definition.json_map_encoded]
  container_definitions_list    = "[${join(",", local.container_definitions_encoded)}]"

  required_envoy_cpu = var.service_connect_configuration != null ? (var.high_traffic_service ? 512 : 256) : 0
  required_envoy_mem = var.service_connect_configuration != null ? (var.high_traffic_service ? 128 : 64) : 0

  required_cpu    = sum([for definition in module.container_definitions : contains(keys(definition.json_map_object), "cpu") ? definition.json_map_object.cpu : 0]) + local.required_envoy_cpu
  required_memory = sum([for definition in module.container_definitions : contains(keys(definition.json_map_object), "memory") ? definition.json_map_object.memory : 0]) + local.required_envoy_mem

  task_definition_tags = merge(
    module.label.tags,
    var.app_version != null ? { "AppVersion" = var.app_version } : {}
  )
}

resource "aws_ecs_task_definition" "this" {
  family                = module.label.id
  container_definitions = local.container_definitions_list

  cpu    = var.task_cpu
  memory = var.task_memory

  task_role_arn      = try(aws_iam_role.task[0].arn, var.task_role.arn)
  execution_role_arn = try(aws_iam_role.execution[0].arn, var.execution_role.arn)

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  dynamic "volume" {
    for_each = var.volumes
    content {
      name = volume.key

      dynamic "efs_volume_configuration" {
        for_each = volume.value.efs == null ? [] : [volume.value.efs]
        content {
          file_system_id          = efs_volume_configuration.value.file_system_id
          root_directory          = efs_volume_configuration.value.root_directory
          transit_encryption      = "ENABLED"
          transit_encryption_port = efs_volume_configuration.value.transit_encryption_port

          # Always emit authorization_config so the secure-by-default
          # `iam = ENABLED` applies even when the consumer didn't set
          # the block — the variable's `{}` default fills in both
          # `access_point_id = null` and `iam = true`.
          authorization_config {
            access_point_id = efs_volume_configuration.value.authorization_config.access_point_id
            iam             = efs_volume_configuration.value.authorization_config.iam ? "ENABLED" : "DISABLED"
          }
        }
      }

      dynamic "s3files_volume_configuration" {
        for_each = volume.value.s3files == null ? [] : [volume.value.s3files]
        content {
          access_point_arn        = s3files_volume_configuration.value.access_point_arn
          file_system_arn         = s3files_volume_configuration.value.file_system_arn
          root_directory          = s3files_volume_configuration.value.root_directory
          transit_encryption_port = s3files_volume_configuration.value.transit_encryption_port
        }
      }
    }
  }

  tags = local.task_definition_tags

  lifecycle {
    # Every container `mount_points[*].sourceVolume` must reference a
    # declared key in `var.volumes`. This crosses two variables, so it
    # can't live in a `validation` block (those see only their own
    # variable) — keep it on the resource that consumes both.
    precondition {
      condition = alltrue(flatten([
        for c in var.container_definitions : [
          for m in coalesce(c.mount_points, []) :
          contains(keys(var.volumes), m.sourceVolume)
        ]
      ]))
      error_message = "Every container `mount_points[*].sourceVolume` must reference a key declared in `var.volumes`. Declared volumes: ${length(var.volumes) == 0 ? "(none)" : join(", ", keys(var.volumes))}."
    }

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
