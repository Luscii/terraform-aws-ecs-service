module "label" {
  source  = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.25.0"
  context = var.context
  name    = var.name
}

module "path" {
  source    = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.25.0"
  context   = module.label.context
  delimiter = "/"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ecs_cluster" "this" {
  cluster_name = var.ecs_cluster_name
}

check "secrets_decryptable" {
  assert {
    condition     = length(var.secrets_arns) == 0 || (length(var.secrets_arns) > 0 && var.secrets_kms_key_arn != "")
    error_message = "If variable 'secrets_arns' is provided, 'secrets_kms_key_arn' must also be provided to allow decryption of the secrets."
  }
}
