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

output "scaling_target" {
  value       = local.scaling_enabled ? aws_appautoscaling_target.this[0] : null
  description = "The autoscaling target resource - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target"
}

output "service_discovery_name" {
  value       = aws_ecs_service.this.service_connect_configuration[0].service[0].discovery_name
  description = "The service discovery name for the service"
}

output "service_discovery_client_aliases" {
  value       = aws_ecs_service.this.service_connect_configuration[0].service[0].client_alias
  description = "The service discovery client aliases for the service"
}

output "service_discovery_internal_url" {
  value       = "http://${aws_ecs_service.this.service_connect_configuration[0].service[0].client_alias[0].dns_name}:${aws_ecs_service.this.service_connect_configuration[0].service[0].client_alias[0].port}"
  description = "Base URL for the service internally"
}
