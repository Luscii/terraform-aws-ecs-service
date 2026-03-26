locals {
  pull_cache_prefixes = toset(distinct(compact([for definition in local.container_definitions :
    contains(keys(definition), "pull_cache_prefix") ? definition.pull_cache_prefix : null
  ])))
}

data "aws_ecr_pull_through_cache_rule" "this" {
  for_each = local.pull_cache_prefixes

  ecr_repository_prefix = each.value
}

locals {
  pull_cache_rule_urls = { for prefix, rule in data.aws_ecr_pull_through_cache_rule.this :
    prefix => "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com/${rule.ecr_repository_prefix}${endswith(rule.ecr_repository_prefix, "/") ? "" : "/"}"
  }
  pull_cache_rule_arns = { for prefix, rule in data.aws_ecr_pull_through_cache_rule.this :
    prefix => "arn:aws:ecr:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:repository/${rule.ecr_repository_prefix}"
  }
}

data "aws_secretsmanager_secret" "pull_through_cache_credentials" {
  for_each = data.aws_ecr_pull_through_cache_rule.this

  arn = each.value.credential_arn
}

locals {
  pull_cache_credential_arns = distinct([for secret in data.aws_secretsmanager_secret.pull_through_cache_credentials : secret.arn])
  pull_cache_kms_key_ids = distinct(compact([for secret in data.aws_secretsmanager_secret.pull_through_cache_credentials :
    secret.kms_key_id
  ]))
  pull_cache_kms_key_arns = distinct(compact([for secret in data.aws_kms_key.pull_through_cache_keys :
    secret.arn
  ]))
}

data "aws_kms_key" "pull_through_cache_keys" {
  for_each = toset(local.pull_cache_kms_key_ids)

  key_id = each.value
}
