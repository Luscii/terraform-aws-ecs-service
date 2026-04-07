resource "aws_cloudwatch_event_rule" "this" {
  count = var.task_schedule == null ? 0 : 1

  name                = module.label.id
  description         = var.task_schedule.description
  schedule_expression = var.task_schedule.schedule
  role_arn            = aws_iam_role.event[0].arn
}

resource "aws_cloudwatch_event_target" "this" {
  count = var.task_schedule == null ? 0 : 1

  target_id = module.label.id
  rule      = aws_cloudwatch_event_rule.this[0].name
  arn       = data.aws_ecs_cluster.this.arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.this.arn
    launch_type         = "FARGATE"

    network_configuration {
      subnets          = var.subnets
      security_groups  = [aws_security_group.this.id]
      assign_public_ip = true
    }
  }

  role_arn = aws_iam_role.event[0].arn
}
