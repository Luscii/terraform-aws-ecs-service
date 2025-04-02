# ############## #
# Execution Role #
# ############## #

data "aws_iam_role" "execution" {
  name = var.execution_role_name
}

resource "aws_iam_role_policy_attachment" "execution_ecr_public" {
  role = data.aws_iam_role.execution.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticContainerRegistryPublicReadOnly"
}

resource "aws_iam_role_policy_attachment" "execution_ecs_task" {
  role = data.aws_iam_role.execution.name

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
}

resource "aws_iam_role_policy" "execution_pull_cache" {
  count = length(data.aws_iam_policy_document.execution_pull_cache) > 0 ? 1 : 0

  name   = join("-", [module.label.id, "ecr-pull-cache"])
  role   = data.aws_iam_role.execution.name
  policy = data.aws_iam_policy_document.execution_pull_cache[count.index].json
}

# ######### #
# Task Role #
# ######### #

data "aws_iam_role" "task" {
  name = var.task_role_name
}

resource "aws_iam_role_policy_attachment" "task_xray_daemon" {
  role = data.aws_iam_role.task.name

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
  role   = data.aws_iam_role.task.name
  policy = data.aws_iam_policy_document.task_ecs_exec
}
