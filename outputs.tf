output "label_context" {
  value       = module.label.context
  description = "Context of the label for subsequent use"
}

output "cluster_name" {
  value       = data.aws_ecs_cluster.this.cluster_name
  description = "The name of the ECS cluster"
}

output "cluster_arn" {
  value       = data.aws_ecs_cluster.this.arn
  description = "The ARN of the ECS cluster"
}

output "task_definition_id" {
  value       = aws_ecs_task_definition.this.id
  description = "The ID of the task definition"
}

output "task_definition_arn" {
  value       = aws_ecs_task_definition.this.arn
  description = "The ARN of the task definition"
}

output "task_definition_family" {
  value       = aws_ecs_task_definition.this.family
  description = "The family of the task definition"
}

output "service_id" {
  value       = aws_ecs_service.this.id
  description = "The ID of the service"
}

output "service_name" {
  value       = aws_ecs_service.this.name
  description = "The name of the service"
}

output "service_arn" {
  value       = aws_ecs_service.this.id
  description = "The ARN of the service"
}

output "service_task_role_arn" {
  value       = try(aws_iam_role.task[0].arn, var.task_role.arn)
  description = "The ARN of the service task role"
}

output "service_execution_role_arn" {
  value       = try(aws_iam_role.execution[0].arn, var.execution_role.arn)
  description = "The ARN of the service execution role"
}

output "scaling_target" {
  value       = local.scaling_enabled ? aws_appautoscaling_target.this[0] : null
  description = "The autoscaling target resource - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target"
}

output "service_discovery_name" {
  value       = try(aws_ecs_service.this.service_connect_configuration[0].service[0].discovery_name, null)
  description = "The service discovery name for the service"
}

output "service_discovery_client_aliases" {
  value       = try(aws_ecs_service.this.service_connect_configuration[0].service[*].client_alias, null)
  description = "The service discovery client aliases for the service"
}

output "service_discovery_internal_url" {
  value       = try("http://${aws_ecs_service.this.service_connect_configuration[0].service[0].client_alias[0].dns_name}:${aws_ecs_service.this.service_connect_configuration[0].service[0].client_alias[0].port}", null)
  description = "Base URL for the service internally"
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "The ID of the security group"
}

output "security_group_arn" {
  value       = aws_security_group.this.arn
  description = "The ARN of the security group"
}
