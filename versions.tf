terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 6.41.0 introduces `volume.s3files_volume_configuration` on
      # `aws_ecs_task_definition`. Required by `type = "s3files"` in
      # `var.volumes`; bumping the floor avoids a confusing schema
      # error on older provider pins.
      version = ">= 6.41.0"
    }
  }
}
