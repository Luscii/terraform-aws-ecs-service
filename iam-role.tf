data "aws_iam_policy_document" "assume_role" {
  count = var.task_role == null || var.execution_role == null ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com", "ecs-tasks.amazonaws.com"]
    }
  }
}

locals {
  # Computed IAM path for the module-created roles. Null when
  # var.iam_role_path is unset, so terraform omits the `path` argument
  # and AWS applies its default (`/`) — preserving prior behaviour for
  # existing consumers.
  role_path = var.iam_role_path == null ? null : "/${var.iam_role_path.service_prefix}/${var.iam_role_path.service_name}/"

  # When `iam_role_path` is set, the path encodes the parent scope so
  # the `namespace` segment is redundant in the role name. Drop it
  # from the label order; keep `environment` / `stage` / `name` /
  # `attributes` so the name stays unique across regions, stays
  # readable about which stage owns the role, and disambiguates
  # multiple services that share a single repo / OIDC consumer.
  # Resulting shape: `<environment>-<stage>-<name>-<roletype>`,
  # e.g. `eu-tst-nhs-mesh-execution`. Falling back to `null` here
  # lets cloudposse label use the consumer's configured label_order
  # (or the cloudposse default, which includes `namespace`).
  role_label_order = var.iam_role_path == null ? null : ["environment", "stage", "name", "attributes"]
}

# One label sub-module per role, mirroring the pattern consumers like
# mesh-client already use for their own role labels. Each role gets a
# `Name` tag derived from its own id (rather than the parent service
# label's id), which makes the IAM console + cost-explorer views
# easier to navigate.
module "execution_role_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  context     = module.label.context
  attributes  = concat(module.label.attributes, ["execution"])
  label_order = local.role_label_order
}

module "task_role_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  context     = module.label.context
  attributes  = concat(module.label.attributes, ["task"])
  label_order = local.role_label_order
}

# ############## #
# Execution Role #
# ############## #

resource "aws_iam_role" "execution" {
  count = var.execution_role == null ? 1 : 0

  name                 = module.execution_role_label.id
  path                 = local.role_path
  permissions_boundary = var.iam_role_permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.assume_role[0].json
  tags                 = module.execution_role_label.tags
}

resource "aws_iam_role_policy_attachment" "execution_ecr_public" {
  role       = try(aws_iam_role.execution[0].name, var.execution_role.name)
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticContainerRegistryPublicReadOnly"
}

resource "aws_iam_role_policy_attachment" "execution_ecs_task" {
  role       = try(aws_iam_role.execution[0].name, var.execution_role.name)
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_pull_cache" {
  count = length(local.pull_cache_rule_arns) > 0 ? 1 : 0

  statement {
    sid    = "ECRPullThroughCache"
    effect = "Allow"

    actions = [
      "ecr:CreateRepository",
      "ecr:BatchImportUpstreamImage"
    ]

    resources = [for arn in values(local.pull_cache_rule_arns) : "${arn}/*"]
  }

  dynamic "statement" {
    for_each = length(local.pull_cache_credential_arns) > 0 ? [1] : []

    content {
      sid       = "ECRPullThroughCacheCredentials"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = local.pull_cache_credential_arns
    }

  }
  dynamic "statement" {
    for_each = length(local.pull_cache_kms_key_arns) > 0 ? [1] : []

    content {
      sid       = "ECRPullThroughCacheKMSEncrypt"
      effect    = "Allow"
      actions   = ["kms:Encrypt", "kms:GenerateDataKey"]
      resources = local.pull_cache_kms_key_arns
    }

  }
}

resource "aws_iam_role_policy" "execution_pull_cache" {
  count = length(data.aws_iam_policy_document.execution_pull_cache) > 0 ? 1 : 0

  name   = join("-", [module.label.id, "ecr-pull-cache"])
  role   = try(aws_iam_role.execution[0].name, var.execution_role.name)
  policy = data.aws_iam_policy_document.execution_pull_cache[count.index].json
}

# ######### #
# Task Role #
# ######### #

resource "aws_iam_role" "task" {
  count = var.task_role == null ? 1 : 0

  name                 = module.task_role_label.id
  path                 = local.role_path
  permissions_boundary = var.iam_role_permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.assume_role[0].json
  tags                 = module.task_role_label.tags
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
