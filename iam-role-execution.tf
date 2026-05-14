module "execution_role_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  context     = module.label.context
  attributes  = ["execution"]
  label_order = local.role_label_order
}

resource "aws_iam_role" "execution" {
  count = var.execution_role == null ? 1 : 0

  name                 = module.execution_role_label.id
  path                 = local.role_path
  permissions_boundary = var.iam_role_permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.assume_role[0].json
  # Preserve the parent-label tag set for consumers on the legacy
  # (path-less) shape so the upgrade is a true no-op for them; opt in
  # to per-role tags only when `iam_role_path` is set.
  tags = var.iam_role_path == null ? module.label.tags : module.execution_role_label.tags
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
