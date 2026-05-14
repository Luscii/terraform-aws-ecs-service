module "task_role_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  context     = module.label.context
  attributes  = ["task"]
  label_order = local.role_label_order
}

resource "aws_iam_role" "task" {
  count = var.task_role == null ? 1 : 0

  name                 = module.task_role_label.id
  path                 = local.role_path
  permissions_boundary = var.iam_role_permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.assume_role[0].json
  # See note on aws_iam_role.execution.tags.
  tags = var.iam_role_path == null ? module.label.tags : module.task_role_label.tags
}

resource "aws_iam_role_policy_attachment" "task_xray_daemon" {
  count = var.add_xray_container ? 1 : 0

  role       = try(aws_iam_role.task[0].name, var.task_role.name)
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

data "aws_iam_policy_document" "task_ecs_exec" {
  count = var.enable_ecs_execute_command ? 1 : 0

  statement {
    sid    = "ECSExec"
    effect = "Allow"

    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task_ecs_exec" {
  count = var.enable_ecs_execute_command ? 1 : 0

  name   = join("-", [module.label.id, "ecs-exec"])
  role   = try(aws_iam_role.task[0].name, var.task_role.name)
  policy = data.aws_iam_policy_document.task_ecs_exec[0].json
}

# ############################################################# #
# Volumes — least-privilege task role policy for EFS / S3 Files #
# ############################################################# #

locals {
  # Volume name → true iff any container mount of this volume has
  # `readOnly = false` (the ECS default). A volume's IAM grants follow
  # the most permissive mount: any RW mount makes the whole volume
  # readable + writable from a IAM perspective. Read-only volumes get
  # only the read-side actions.
  volume_is_rw = {
    for name in keys(var.volumes) :
    name => anytrue(flatten([
      for c in var.container_definitions : [
        for m in coalesce(c.mount_points, []) :
        m.sourceVolume == name && !m.readOnly
      ]
    ]))
  }

  # EFS statement specs. One per volume that (a) is type=efs and
  # (b) has authorization_config.iam=true. Ephemeral and POSIX-only
  # EFS contribute nothing.
  #
  # Each spec carries an `attach` flag indicating whether this volume's
  # `attach_iam_policy` is true. Two data sources read these specs:
  # `task_volumes` (full — for the `volume_iam_policy_json` output)
  # iterates every spec; `task_volumes_attached` (inline — for the role
  # policy resource) filters to `attach = true` only. This split keeps
  # the documented opt-out path working: the full JSON stays exposed
  # for consumers to attach themselves, while the module's own inline
  # policy never grants permissions for volumes whose owners opted out.
  volume_efs_statements = [
    for name, v in var.volumes : {
      sid       = "EfsClient${replace(name, "/[^A-Za-z0-9]/", "")}"
      file_arn  = "arn:aws:elasticfilesystem:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:file-system/${v.efs.file_system_id}"
      ap_id     = try(v.efs.authorization_config.access_point_id, null)
      access_pt = try(v.efs.authorization_config.access_point_id, null) == null ? null : "arn:aws:elasticfilesystem:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:access-point/${v.efs.authorization_config.access_point_id}"
      actions = concat(
        ["elasticfilesystem:ClientMount"],
        local.volume_is_rw[name] ? ["elasticfilesystem:ClientWrite"] : [],
        # ClientRootAccess only when RW *and* no access point — access
        # points already root-scope the mount, making the action
        # redundant and over-broad. Without an access point, the only
        # way to write to the FS root is to grant it explicitly.
        local.volume_is_rw[name] && try(v.efs.authorization_config.access_point_id, null) == null ? ["elasticfilesystem:ClientRootAccess"] : [],
      )
      attach = v.attach_iam_policy
    }
    if v.type == "efs" && try(v.efs.authorization_config.iam, false)
  ]

  # S3 Files statement specs. Two per s3files volume — the bucket-level
  # `s3:ListBucket` and the object-level `s3:GetObject`/`PutObject`/
  # `DeleteObject` — because the two action sets need different
  # resource ARNs. AWS access points scope bucket-level actions to the
  # access point ARN itself, but object-level actions require the
  # `<access-point-arn>/object/*` form. Granting `s3:GetObject` on the
  # bare access point ARN silently grants nothing at runtime.
  # See the `attach` note on `volume_efs_statements`.
  volume_s3files_statements = flatten([
    for name, v in var.volumes : [
      {
        sid       = "S3FilesList${replace(name, "/[^A-Za-z0-9]/", "")}"
        actions   = ["s3:ListBucket"]
        resources = [v.s3files.access_point_arn]
        attach    = v.attach_iam_policy
      },
      {
        sid = "S3FilesObjects${replace(name, "/[^A-Za-z0-9]/", "")}"
        actions = concat(
          ["s3:GetObject"],
          local.volume_is_rw[name] ? ["s3:PutObject", "s3:DeleteObject"] : [],
        )
        resources = ["${v.s3files.access_point_arn}/object/*"]
        attach    = v.attach_iam_policy
      }
    ]
    if v.type == "s3files"
  ])

  # KMS keys grouped by ARN with the per-key RW signal aggregated
  # across volumes that reference them. Two parallel maps:
  # `volume_kms_rw_by_key` (full — for the output) covers every volume
  # that *actually contributes IAM*; `volume_kms_rw_by_key_attached`
  # (for the inline policy) further restricts to volumes with
  # `attach_iam_policy = true`. A key is RW iff any contributing
  # volume mounting it is RW.
  #
  # EFS contributes its `kms_key_arn` only when `authorization_config.iam = true`.
  # POSIX-only EFS volumes don't authenticate the mount via the task
  # role, so granting KMS on the task role for that volume is
  # over-broad — and inconsistent with the rest of the policy
  # computation, which already excludes those volumes from the EFS
  # statement list. S3 Files volumes always use IAM, so their
  # `kms_key_arn` always contributes.
  volume_kms_rw_by_key = {
    for kms_arn in distinct(flatten([
      for v in values(var.volumes) :
      concat(
        (v.type == "efs" && try(v.efs.authorization_config.iam, false))
        ? compact([try(v.efs.kms_key_arn, null)]) : [],
        v.type == "s3files"
        ? compact([try(v.s3files.kms_key_arn, null)]) : [],
      )
    ])) :
    kms_arn => anytrue([
      for name, v in var.volumes :
      local.volume_is_rw[name]
      if(
        (v.type == "efs" && try(v.efs.authorization_config.iam, false) && try(v.efs.kms_key_arn, null) == kms_arn) ||
        (v.type == "s3files" && try(v.s3files.kms_key_arn, null) == kms_arn)
      )
    ])
  }

  volume_kms_rw_by_key_attached = {
    for kms_arn in distinct(flatten([
      for v in values(var.volumes) :
      v.attach_iam_policy ? concat(
        (v.type == "efs" && try(v.efs.authorization_config.iam, false))
        ? compact([try(v.efs.kms_key_arn, null)]) : [],
        v.type == "s3files"
        ? compact([try(v.s3files.kms_key_arn, null)]) : [],
      ) : []
    ])) :
    kms_arn => anytrue([
      for name, v in var.volumes :
      local.volume_is_rw[name]
      if v.attach_iam_policy && (
        (v.type == "efs" && try(v.efs.authorization_config.iam, false) && try(v.efs.kms_key_arn, null) == kms_arn) ||
        (v.type == "s3files" && try(v.s3files.kms_key_arn, null) == kms_arn)
      )
    ])
  }

  # Attach-only views of the statement specs, used by
  # `data.aws_iam_policy_document.task_volumes_attached`.
  volume_efs_statements_attached     = [for s in local.volume_efs_statements : s if s.attach]
  volume_s3files_statements_attached = [for s in local.volume_s3files_statements : s if s.attach]

  volume_policy_has_statements = length(local.volume_efs_statements) + length(local.volume_s3files_statements) + length(local.volume_kms_rw_by_key) > 0

  # Whether the module should actually attach `aws_iam_role_policy.task_volumes`
  # inline to the task role. True iff any volume that *would* contribute
  # statements also has `attach_iam_policy = true`. When every contributing
  # volume opts out, the full JSON is still computed (and exposed via the
  # output) but no role policy resource is created.
  volume_policy_should_attach = anytrue([
    for name, v in var.volumes :
    v.attach_iam_policy && (
      (v.type == "efs" && try(v.efs.authorization_config.iam, false)) ||
      v.type == "s3files"
    )
  ])
}

data "aws_iam_policy_document" "task_volumes" {
  count = local.volume_policy_has_statements ? 1 : 0

  dynamic "statement" {
    for_each = local.volume_efs_statements
    content {
      sid       = statement.value.sid
      effect    = "Allow"
      actions   = statement.value.actions
      resources = [statement.value.file_arn]

      dynamic "condition" {
        for_each = statement.value.access_pt == null ? [] : [statement.value.access_pt]
        content {
          test     = "StringEquals"
          variable = "elasticfilesystem:AccessPointArn"
          values   = [condition.value]
        }
      }
    }
  }

  dynamic "statement" {
    for_each = local.volume_s3files_statements
    content {
      sid       = statement.value.sid
      effect    = "Allow"
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }

  dynamic "statement" {
    for_each = local.volume_kms_rw_by_key
    content {
      sid    = "Kms${replace(statement.key, "/[^A-Za-z0-9]/", "")}"
      effect = "Allow"
      actions = concat(
        ["kms:Decrypt"],
        statement.value ? ["kms:Encrypt", "kms:GenerateDataKey"] : [],
      )
      resources = [statement.key]
    }
  }
}

data "aws_iam_policy_document" "task_volumes_attached" {
  count = local.volume_policy_should_attach ? 1 : 0

  dynamic "statement" {
    for_each = local.volume_efs_statements_attached
    content {
      sid       = statement.value.sid
      effect    = "Allow"
      actions   = statement.value.actions
      resources = [statement.value.file_arn]

      dynamic "condition" {
        for_each = statement.value.access_pt == null ? [] : [statement.value.access_pt]
        content {
          test     = "StringEquals"
          variable = "elasticfilesystem:AccessPointArn"
          values   = [condition.value]
        }
      }
    }
  }

  dynamic "statement" {
    for_each = local.volume_s3files_statements_attached
    content {
      sid       = statement.value.sid
      effect    = "Allow"
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }

  dynamic "statement" {
    for_each = local.volume_kms_rw_by_key_attached
    content {
      sid    = "Kms${replace(statement.key, "/[^A-Za-z0-9]/", "")}"
      effect = "Allow"
      actions = concat(
        ["kms:Decrypt"],
        statement.value ? ["kms:Encrypt", "kms:GenerateDataKey"] : [],
      )
      resources = [statement.key]
    }
  }
}

resource "aws_iam_role_policy" "task_volumes" {
  count = local.volume_policy_should_attach ? 1 : 0

  name   = join("-", [module.label.id, "volumes"])
  role   = try(aws_iam_role.task[0].name, var.task_role.name)
  policy = data.aws_iam_policy_document.task_volumes_attached[0].json
}
