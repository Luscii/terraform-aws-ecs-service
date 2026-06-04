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
