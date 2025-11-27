resource "aws_cloudwatch_log_group" "this" {
  count             = var.cloudwatch_log_group_arn == "" ? 1 : 0
  name              = module.path.id
  tags              = module.path.tags
  retention_in_days = var.log_retention_in_days
}

check "log_group_has_retention" {
  assert {
    condition     = var.cloudwatch_log_group_arn == "" || var.log_retention_in_days != null
    error_message = "When creating a CloudWatch log group, log_retention_in_days must be set to a non-null value."
  }
}
