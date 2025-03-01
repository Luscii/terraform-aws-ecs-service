locals {
  container_names = [for definition in local.container_definitions : definition.sensitive_json_map_object.name]

  container_port_names          = { for definition in local.container_definitions : definition.sensitive_json_map_object.name => definition.sensitive_json_map_object.portMappings[*].containerPort }
  load_balancer_container_names = length(var.load_balancers) > 0 ? [for lb in var.load_balancers : lb.container_name] : []
}

resource "aws_ecs_service" "this" {
  name = module.label.id

  cluster          = data.aws_ecs_cluster.this.arn
  task_definition  = aws_ecs_task_definition.this.arn
  launch_type      = "FARGATE"
  platform_version = var.platform_version

  enable_execute_command = var.enable_ecs_execute_command

  desired_count                      = var.desired_count
  force_new_deployment               = var.force_new_deployment
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 400
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnets
    security_groups  = concat([aws_security_group.this.id], var.security_group_ids)
    assign_public_ip = var.assign_public_ip
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.service_connect_configuration.namespace

    service {
      discovery_name = var.service_connect_configuration.discovery_name
      port_name      = var.service_connect_configuration.port_name

      client_alias {
        dns_name = var.service_connect_configuration.client_alias.dns_name
        port     = var.service_connect_configuration.client_alias.port
      }
    }

    dynamic "log_configuration" {
      for_each = var.service_connect_configuration.cloudwatch != null ? [var.service_connect_configuration.cloudwatch] : []

      content {
        log_driver = "awslogs"
        options = {
          "awslogs-group"         = log_configuration.value.log_group
          "awslogs-region"        = log_configuration.value.region
          "awslogs-stream-prefix" = "service-connect"
        }
      }
    }
  }

  dynamic "load_balancer" {
    for_each = var.load_balancers

    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  tags = module.label.tags

  depends_on = [aws_iam_role_policy_attachment.execution_ecs_task]

  lifecycle {
    ignore_changes = [desired_count]

    precondition {
      condition     = contains(local.container_port_names, var.service_connect_configuration.port_name)
      error_message = "Port name must be one of the container port names"
    }
    precondition {
      condition     = length(local.load_balancer_container_names) == 0 || alltrue([for name in local.load_balancer_container_names : contains(local.container_names, name)])
      error_message = "Load Balancer container name must be one of the container names"
    }
    precondition {
      condition     = length(local.load_balancer_container_names) == 0 || alltrue([for lb in var.load_balancers : contains(local.container_port_names[lb.container_name], lb.container_port)])
      error_message = "Load Balancer container port must be one of the container ports"
    }
  }
}
