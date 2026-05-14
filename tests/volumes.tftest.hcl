mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name             = "test-service"
  task_cpu         = 256
  task_memory      = 512
  vpc_id           = "vpc-12345678"
  subnets          = ["subnet-aaaaaaaa", "subnet-bbbbbbbb"]
  ecs_cluster_name = "test-cluster"

  container_definitions = [
    {
      name  = "app"
      image = "nginx:latest"
      port_mappings = [
        { containerPort = 80 }
      ]
    }
  ]
}

# ---------------------------------------------------------------------- #
# Default and ephemeral
# ---------------------------------------------------------------------- #

run "default_volumes_is_noop" {
  command = plan

  assert {
    condition     = length(aws_ecs_task_definition.this.volume) == 0
    error_message = "Default var.volumes = {} should produce no volume blocks on the task definition"
  }

  assert {
    condition     = length(aws_iam_role_policy.task_volumes) == 0
    error_message = "Default var.volumes = {} should produce no task_volumes IAM policy"
  }
}

run "ephemeral_volume_renders_bare_volume_block" {
  command = plan

  variables {
    volumes = {
      scratch = { type = "ephemeral" }
    }
  }

  assert {
    condition     = length(aws_ecs_task_definition.this.volume) == 1
    error_message = "Expected exactly one volume block on the task definition"
  }

  assert {
    condition     = tolist(aws_ecs_task_definition.this.volume)[0].name == "scratch"
    error_message = "Expected volume name = scratch"
  }

  assert {
    condition     = length(tolist(aws_ecs_task_definition.this.volume)[0].efs_volume_configuration) == 0
    error_message = "Ephemeral volume must not render any efs_volume_configuration block"
  }

  assert {
    condition     = length(tolist(aws_ecs_task_definition.this.volume)[0].s3files_volume_configuration) == 0
    error_message = "Ephemeral volume must not render any s3files_volume_configuration block"
  }

  assert {
    condition     = length(aws_iam_role_policy.task_volumes) == 0
    error_message = "Ephemeral volumes contribute no IAM statements; no policy should be created"
  }
}

# ---------------------------------------------------------------------- #
# EFS — defaults, opt-out of IAM auth, access point, kms_key_arn
# ---------------------------------------------------------------------- #

run "efs_volume_with_iam_auth_default_renders_block_and_policy" {
  command = plan

  variables {
    volumes = {
      data = {
        type = "efs"
        efs  = { file_system_id = "fs-12345678" }
      }
    }
  }

  assert {
    condition     = length(tolist(aws_ecs_task_definition.this.volume)[0].efs_volume_configuration) == 1
    error_message = "Expected efs_volume_configuration block on the volume"
  }

  assert {
    condition     = tolist(aws_ecs_task_definition.this.volume)[0].efs_volume_configuration[0].file_system_id == "fs-12345678"
    error_message = "Expected file_system_id passthrough"
  }

  assert {
    condition     = tolist(aws_ecs_task_definition.this.volume)[0].efs_volume_configuration[0].transit_encryption == "ENABLED"
    error_message = "Expected transit_encryption = ENABLED by default"
  }

  assert {
    condition     = tolist(aws_ecs_task_definition.this.volume)[0].efs_volume_configuration[0].authorization_config[0].iam == "ENABLED"
    error_message = "Expected EFS IAM authorization ENABLED by default"
  }

  assert {
    condition     = length(aws_iam_role_policy.task_volumes) == 1
    error_message = "EFS volume with IAM auth on must attach the volumes policy to the task role"
  }
}

run "efs_volume_with_iam_auth_off_renders_block_but_no_policy" {
  command = plan

  variables {
    volumes = {
      data = {
        type = "efs"
        efs = {
          file_system_id       = "fs-12345678"
          authorization_config = { iam = false }
        }
      }
    }
  }

  assert {
    condition     = tolist(aws_ecs_task_definition.this.volume)[0].efs_volume_configuration[0].authorization_config[0].iam == "DISABLED"
    error_message = "Expected EFS IAM authorization DISABLED when iam = false"
  }

  assert {
    condition     = length(aws_iam_role_policy.task_volumes) == 0
    error_message = "POSIX-only EFS mount (iam = false) needs no IAM policy"
  }
}

run "efs_volume_with_access_point_renders_in_authorization_config" {
  command = plan

  variables {
    volumes = {
      patient = {
        type = "efs"
        efs = {
          file_system_id = "fs-12345678"
          authorization_config = {
            access_point_id = "fsap-aaaabbbbccccdddd"
          }
        }
      }
    }
  }

  assert {
    condition     = tolist(aws_ecs_task_definition.this.volume)[0].efs_volume_configuration[0].authorization_config[0].access_point_id == "fsap-aaaabbbbccccdddd"
    error_message = "Expected access_point_id to render under authorization_config"
  }

  assert {
    condition     = length(aws_iam_role_policy.task_volumes) == 1
    error_message = "EFS with access point + IAM auth default-on should attach a policy"
  }
}

run "efs_volume_with_kms_key_arn_still_attaches_policy" {
  command = plan

  variables {
    volumes = {
      data = {
        type = "efs"
        efs = {
          file_system_id = "fs-12345678"
          kms_key_arn    = "arn:aws:kms:eu-west-2:123456789012:key/abcd1234-ef56-7890-abcd-ef1234567890"
        }
      }
    }
  }

  assert {
    condition     = length(aws_iam_role_policy.task_volumes) == 1
    error_message = "EFS with KMS key + IAM auth on must attach the policy"
  }
}

# ---------------------------------------------------------------------- #
# S3 Files
# ---------------------------------------------------------------------- #

run "s3files_volume_renders_block_and_policy" {
  command = plan

  variables {
    volumes = {
      mesh = {
        type = "s3files"
        s3files = {
          access_point_arn = "arn:aws:s3:eu-west-2:123456789012:accesspoint/mesh-mountpoint-ap"
          file_system_arn  = "arn:aws:s3files:eu-west-2:123456789012:filesystem/fs-mesh"
        }
      }
    }
  }

  assert {
    condition     = length(tolist(aws_ecs_task_definition.this.volume)[0].s3files_volume_configuration) == 1
    error_message = "Expected s3files_volume_configuration block on the volume"
  }

  assert {
    condition     = tolist(aws_ecs_task_definition.this.volume)[0].s3files_volume_configuration[0].access_point_arn == "arn:aws:s3:eu-west-2:123456789012:accesspoint/mesh-mountpoint-ap"
    error_message = "Expected access_point_arn passthrough"
  }

  assert {
    condition     = tolist(aws_ecs_task_definition.this.volume)[0].s3files_volume_configuration[0].file_system_arn == "arn:aws:s3files:eu-west-2:123456789012:filesystem/fs-mesh"
    error_message = "Expected file_system_arn passthrough"
  }

  assert {
    condition     = length(aws_iam_role_policy.task_volumes) == 1
    error_message = "S3 Files volume should attach the volumes policy by default"
  }
}

# ---------------------------------------------------------------------- #
# Mixed and opt-out
# ---------------------------------------------------------------------- #

run "mixed_volume_types_render_three_blocks" {
  command = plan

  variables {
    volumes = {
      scratch = { type = "ephemeral" }
      data = {
        type = "efs"
        efs  = { file_system_id = "fs-12345678" }
      }
      mesh = {
        type = "s3files"
        s3files = {
          access_point_arn = "arn:aws:s3:eu-west-2:123456789012:accesspoint/mesh-ap"
          file_system_arn  = "arn:aws:s3files:eu-west-2:123456789012:filesystem/fs-mesh"
        }
      }
    }
  }

  assert {
    condition     = length([for v in aws_ecs_task_definition.this.volume : v.name if v.name == "scratch"]) == 1
    error_message = "Expected a volume named scratch in the rendered set"
  }

  assert {
    condition     = length([for v in aws_ecs_task_definition.this.volume : v.name if v.name == "data"]) == 1
    error_message = "Expected a volume named data in the rendered set"
  }

  assert {
    condition     = length([for v in aws_ecs_task_definition.this.volume : v.name if v.name == "mesh"]) == 1
    error_message = "Expected a volume named mesh in the rendered set"
  }

  assert {
    condition     = length(aws_iam_role_policy.task_volumes) == 1
    error_message = "Mixed set with EFS+S3 Files contributors should still attach one combined policy"
  }
}

run "attach_iam_policy_false_skips_policy_resource" {
  command = plan

  variables {
    volumes = {
      data = {
        type              = "efs"
        attach_iam_policy = false
        efs               = { file_system_id = "fs-12345678" }
      }
    }
  }

  assert {
    condition     = length(tolist(aws_ecs_task_definition.this.volume)) == 1
    error_message = "attach_iam_policy = false must still render the volume block"
  }

  assert {
    condition     = length(aws_iam_role_policy.task_volumes) == 0
    error_message = "attach_iam_policy = false must not attach an inline policy"
  }
}

# ---------------------------------------------------------------------- #
# Validation and precondition failures
# ---------------------------------------------------------------------- #

run "validation_rejects_invalid_type" {
  command = plan

  variables {
    volumes = {
      bad = { type = "host_path" }
    }
  }

  expect_failures = [var.volumes]
}

run "validation_rejects_type_subblock_mismatch" {
  command = plan

  variables {
    volumes = {
      bad = {
        type = "ephemeral"
        efs  = { file_system_id = "fs-12345678" }
      }
    }
  }

  expect_failures = [var.volumes]
}

run "precondition_rejects_undeclared_source_volume" {
  command = plan

  variables {
    volumes = {
      data = {
        type = "efs"
        efs  = { file_system_id = "fs-12345678" }
      }
    }
    container_definitions = [
      {
        name  = "app"
        image = "nginx:latest"
        mount_points = [
          { sourceVolume = "typo-not-data", containerPath = "/mnt/data" }
        ]
      }
    ]
  }

  expect_failures = [aws_ecs_task_definition.this]
}
