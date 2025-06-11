# ############## #
# Execution Role #
# ############## #


resource "aws_iam_role_policy_attachment" "execution_ecr_public" {
  role = var.execution_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticContainerRegistryPublicReadOnly"
}

resource "aws_iam_role_policy_attachment" "execution_ecs_task" {
  role = var.execution_role.name

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
    sid    = "ECRPullThroughCacheCredentials"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = concat(local.pull_cache_credential_arns)
  }
  dynamic "statement" {
    for_each = length(local.pull_cache_credential_kms_keys) > 0 ? [1] : []

    content {
      sid    = "ECRPullThroughCacheKMS"
      effect = "Allow"
      actions = [
        "kms:Decrypt"
      ]
      resources = [for key in local.pull_cache_credential_kms_keys : data.aws_kms_key.pull_cache_credential_kms_keys[key].arn]
    }
  }
}

resource "aws_iam_role_policy" "execution_pull_cache" {
  count = length(data.aws_iam_policy_document.execution_pull_cache) > 0 ? 1 : 0

  name   = join("-", [module.label.id, "ecr-pull-cache"])
  role   = var.execution_role.name
  policy = data.aws_iam_policy_document.execution_pull_cache[count.index].json
}

# ######### #
# Task Role #
# ######### #

resource "aws_iam_role_policy_attachment" "task_xray_daemon" {
  count = var.add_xray_container ? 1 : 0

  role = var.task_role.name

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
  role   = var.task_role.name
  policy = data.aws_iam_policy_document.task_ecs_exec.json
}
