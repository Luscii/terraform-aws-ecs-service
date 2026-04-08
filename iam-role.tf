data "aws_iam_policy_document" "assume_role" {
  count = var.task_role == null || var.execution_role == null || var.task_schedule != null ? 1 : 0

  dynamic "statement" {
    for_each = var.task_role != null || var.execution_role != null ? [1] : []

    content {
      actions = ["sts:AssumeRole"]

      principals {
        type = "Service"
        identifiers = [
          "ecs.amazonaws.com",
          "ecs-tasks.amazonaws.com"
        ]
      }
    }
  }

  dynamic "statement" {
    for_each = var.task_schedule != null ? [1] : []

    content {
      actions = ["sts:AssumeRole"]

      principals {
        type = "Service"
        identifiers = [
          "ecs-tasks.amazonaws.com",
          "events.amazonaws.com"
        ]
      }
    }
  }
}

# ############## #
# Execution Role #
# ############## #

resource "aws_iam_role" "execution" {
  count = var.execution_role == null ? 1 : 0

  name               = join("-", [module.label.id, "execution"])
  assume_role_policy = data.aws_iam_policy_document.assume_role[0].json
  tags               = module.label.tags
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

  name               = join("-", [module.label.id, "task"])
  assume_role_policy = data.aws_iam_policy_document.assume_role[0].json
  tags               = module.label.tags
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

##############
# Event Role #
##############

data "aws_iam_policy_document" "event_role" {
  count = var.task_schedule == null ? 0 : 1

  statement {
    effect    = "Allow"
    actions   = ["ecs:RunTask"]
    resources = [aws_ecs_task_definition.this.arn]
  }

  statement {
    effect  = "Allow"
    actions = ["iam:PassRole"]

    resources = [
      try(aws_iam_role.execution[0].arn, var.execution_role.arn),
      try(aws_iam_role.task[0].arn, var.task_role.arn),
    ]

    condition {
      test     = "StringLike"
      values   = ["ecs-tasks.amazonaws.com"]
      variable = "iam:PassedToService"
    }
  }
}

resource "aws_iam_role" "event" {
  count = var.task_schedule == null ? 0 : 1

  name               = join("-", [module.label.id, "event"])
  assume_role_policy = data.aws_iam_policy_document.assume_role[0].json
  tags               = module.label.tags
}

resource "aws_iam_role_policy" "event" {
  count = var.task_schedule == null ? 0 : 1

  name   = join("-", [module.label.id, "event"])
  role   = aws_iam_role.event[0].id
  policy = data.aws_iam_policy_document.event_role[0].json
}
