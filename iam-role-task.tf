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

  # EFS statement specs. One per volume that (a) is type=efs, (b) has
  # attach_iam_policy=true, (c) has authorization_config.iam=true.
  # Ephemeral and POSIX-only EFS contribute nothing.
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
    }
    if v.type == "efs" && v.attach_iam_policy && try(v.efs.authorization_config.iam, false)
  ]

  # S3 Files statement specs. One per volume that's type=s3files with
  # attach_iam_policy=true.
  volume_s3files_statements = [
    for name, v in var.volumes : {
      sid              = "S3Files${replace(name, "/[^A-Za-z0-9]/", "")}"
      access_point_arn = v.s3files.access_point_arn
      actions = concat(
        ["s3:GetObject", "s3:ListBucket"],
        local.volume_is_rw[name] ? ["s3:PutObject", "s3:DeleteObject"] : [],
      )
    }
    if v.type == "s3files" && v.attach_iam_policy
  ]

  # KMS keys grouped by ARN with the per-key RW signal aggregated
  # across all volumes that reference them. A key is RW iff any
  # volume mounting it is RW. `compact` drops nulls without the
  # coalesce-on-empty trap (ephemeral volumes have neither efs nor
  # s3files set, so both try() expressions resolve to null).
  volume_kms_rw_by_key = {
    for kms_arn in distinct(flatten([
      for v in values(var.volumes) :
      v.attach_iam_policy ? compact([
        try(v.efs.kms_key_arn, null),
        try(v.s3files.kms_key_arn, null),
      ]) : []
    ])) :
    kms_arn => anytrue([
      for name, v in var.volumes :
      local.volume_is_rw[name]
      if v.attach_iam_policy && (
        try(v.efs.kms_key_arn, null) == kms_arn ||
        try(v.s3files.kms_key_arn, null) == kms_arn
      )
    ])
  }

  volume_policy_has_statements = length(local.volume_efs_statements) + length(local.volume_s3files_statements) + length(local.volume_kms_rw_by_key) > 0
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
      resources = [statement.value.access_point_arn]
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

resource "aws_iam_role_policy" "task_volumes" {
  count = local.volume_policy_has_statements ? 1 : 0

  name   = join("-", [module.label.id, "volumes"])
  role   = try(aws_iam_role.task[0].name, var.task_role.name)
  policy = data.aws_iam_policy_document.task_volumes[0].json
}
