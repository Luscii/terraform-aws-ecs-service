resource "aws_cloudwatch_event_rule" "this" {
  count = var.scheduled_task == null ? 0 : 1

  name                = module.label.id
  description         = var.scheduled_task.description
  schedule_expression = var.scheduled_task.schedule
  role_arn            = aws_iam_role.event[0].arn
  state               = var.scheduled_task.enabled ? "ENABLED" : "DISABLED"
  tags                = module.label.tags
}

resource "aws_cloudwatch_event_target" "this" {
  count = var.scheduled_task == null ? 0 : 1

  target_id = module.label.id
  rule      = aws_cloudwatch_event_rule.this[0].name
  arn       = data.aws_ecs_cluster.this.arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.this.arn
    launch_type         = "FARGATE"
    task_count          = var.scheduled_task.task_count

    network_configuration {
      subnets          = var.subnets
      security_groups  = concat([aws_security_group.this.id], var.security_group_ids)
      assign_public_ip = var.scheduled_task.assign_public_ip
    }
  }

  role_arn = aws_iam_role.event[0].arn
}
