locals {
  cloudwatch_log_group_arn = try(aws_cloudwatch_log_group.this[0].arn, var.cloudwatch_log_group_arn)
}

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

# ############## #
# Execution Role #
# ############## #

data "aws_iam_policy_document" "execution_role" {
  count = var.execution_role == null ? 1 : 0

  statement {
    sid    = "cloudwatchAccess"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      local.cloudwatch_log_group_arn,
      "${local.cloudwatch_log_group_arn}:*"
    ]
  }
}

data "aws_iam_policy_document" "execution_role_secrets" {
  count = length(var.secrets_arns) > 0 && var.execution_role == null ? 1 : 0

  statement {
    sid       = "secretManagerAccess"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = var.secrets_arns
  }

  statement {
    sid       = "kmsDecrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.secrets_kms_key_arn]
  }
}

resource "aws_iam_role" "execution_role" {
  count = var.execution_role == null ? 1 : 0

  name               = join("-", [module.label.id, "execution"])
  assume_role_policy = data.aws_iam_policy_document.assume_role[0].json
  tags               = module.label.tags
}

resource "aws_iam_role_policy" "execution_role" {
  count = var.execution_role == null ? 1 : 0

  name   = join("-", [module.label.id, "execution"])
  role   = aws_iam_role.execution_role[0].id
  policy = data.aws_iam_policy_document.execution_role[0].json
}

resource "aws_iam_role_policy" "execution_role_secrets" {
  count = length(var.secrets_arns) > 0 && var.execution_role == null ? 1 : 0

  name   = join("-", [module.label.id, "execution-secrets"])
  role   = aws_iam_role.execution_role[0].id
  policy = data.aws_iam_policy_document.execution_role_secrets[0].json
}

resource "aws_iam_role_policy_attachment" "execution_ecr_public" {
  role       = try(aws_iam_role.execution_role[0].name, var.execution_role.name)
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticContainerRegistryPublicReadOnly"
}

resource "aws_iam_role_policy_attachment" "execution_ecs_task" {
  role       = try(aws_iam_role.execution_role[0].name, var.execution_role.name)
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

  statement {
    sid       = "ECRPullThroughCacheCredentials"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = local.pull_cache_credential_arns
  }
}

resource "aws_iam_role_policy" "execution_pull_cache" {
  count = length(data.aws_iam_policy_document.execution_pull_cache) > 0 ? 1 : 0

  name   = join("-", [module.label.id, "ecr-pull-cache"])
  role   = try(aws_iam_role.execution_role[0].name, var.execution_role.name)
  policy = data.aws_iam_policy_document.execution_pull_cache[count.index].json
}

# ######### #
# Task Role #
# ######### #

resource "aws_iam_role" "task_role" {
  count = var.task_role == null ? 1 : 0

  name               = join("-", [module.label.id, "task"])
  assume_role_policy = data.aws_iam_policy_document.assume_role[0].json
  tags               = module.label.tags
}

resource "aws_iam_role_policy_attachment" "task_xray_daemon" {
  count = var.add_xray_container ? 1 : 0

  role       = try(aws_iam_role.task_role[0].name, var.task_role.name)
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

data "aws_iam_policy_document" "task_ecs_exec" {
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
  role   = try(aws_iam_role.task_role[0].name, var.task_role.name)
  policy = data.aws_iam_policy_document.task_ecs_exec.json
}
