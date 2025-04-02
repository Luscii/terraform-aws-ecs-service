# terraform-aws-ecs-service
Create a ECS (fargate) service following Luscii standards

## Examples

### With Load Balancer
```terraform
module "lb_service" {

}
```

### Without Load Balancer (Service Connect only)

```terraform
module "sc_service" {

}
```

## Configuration
<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.9 |

### Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.89.0 |

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_autoscaling_label"></a> [autoscaling\_label](#module\_autoscaling\_label) | cloudposse/label/null | 0.25.0 |
| <a name="module_autoscaling_scheduled_label"></a> [autoscaling\_scheduled\_label](#module\_autoscaling\_scheduled\_label) | cloudposse/label/null | 0.25.0 |
| <a name="module_autoscaling_target_tracking_label"></a> [autoscaling\_target\_tracking\_label](#module\_autoscaling\_target\_tracking\_label) | cloudposse/label/null | 0.25.0 |
| <a name="module_container_definitions"></a> [container\_definitions](#module\_container\_definitions) | cloudposse/ecs-container-definition/aws | 0.61.2 |
| <a name="module_label"></a> [label](#module\_label) | cloudposse/label/null | 0.25.0 |

### Resources

| Name | Type |
|------|------|
| [aws_appautoscaling_policy.target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_scheduled_action.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_scheduled_action) | resource |
| [aws_appautoscaling_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role_policy.execution_pull_cache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.task_ecs_exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.execution_ecr_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.execution_ecs_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task_xray_daemon](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ecr_pull_through_cache_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_pull_through_cache_rule) | data source |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_cluster) | data source |
| [aws_iam_policy_document.execution_pull_cache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.task_ecs_exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role) | data source |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Whether the service needs a public ip | `bool` | `false` | no |
| <a name="input_container_definitions"></a> [container\_definitions](#input\_container\_definitions) | List of container definitions, accepts the inputs of the module https://github.com/cloudposse/terraform-aws-ecs-container-definition | <pre>list(object({<br/>    name              = string<br/>    image             = string<br/>    pull_cache_prefix = optional(string, "")<br/><br/>    cpu                = optional(number)<br/>    memory             = optional(number)<br/>    memory_reservation = optional(number)<br/><br/>    depends_on = optional(list(object({<br/>      condition     = string<br/>      containerName = string<br/>      }))<br/>    )<br/>    essential = optional(bool, true)<br/><br/>    port_mappings = optional(list(object({<br/>      containerPort = number<br/>      protocol      = optional(string, "tcp")<br/>      name          = optional(string)<br/>    })))<br/><br/>    healthcheck = optional(object({<br/>      command     = list(string)<br/>      interval    = optional(number)<br/>      retries     = optional(number)<br/>      startPeriod = optional(number)<br/>      timeout     = optional(number)<br/>    }))<br/>    entrypoint        = optional(list(string))<br/>    command           = optional(list(string))<br/>    working_directory = optional(string)<br/>    environment = optional(list(object({<br/>      name  = string<br/>      value = string<br/>    })))<br/>    secrets = optional(list(object({<br/>      name      = string<br/>      valueFrom = string<br/>    })))<br/>    log_configuration = optional(object({<br/>      logDriver = string<br/>      options   = optional(map(string))<br/>      secretOptions = optional(list(object({<br/>        name      = string<br/>        valueFrom = string<br/>      })))<br/>    }))<br/>    ulimits = optional(list(object({<br/>      hardLimit = number<br/>      name      = string<br/>      softLimit = number<br/>    })))<br/>    user          = optional(string)<br/>    start_timeout = optional(number)<br/>    stop_timeout  = optional(number)<br/>  }))</pre> | n/a | yes |
| <a name="input_context"></a> [context](#input\_context) | Single object for setting entire context at once.<br/>See description of individual variables for details.<br/>Leave string and numeric variables as `null` to use default value.<br/>Individual variable settings (non-null) override settings in context object,<br/>except for attributes, tags, and additional\_tag\_map, which are merged. | `any` | <pre>{<br/>  "additional_tag_map": {},<br/>  "attributes": [],<br/>  "delimiter": null,<br/>  "descriptor_formats": {},<br/>  "enabled": true,<br/>  "environment": null,<br/>  "id_length_limit": null,<br/>  "label_key_case": null,<br/>  "label_order": [],<br/>  "label_value_case": null,<br/>  "labels_as_tags": [<br/>    "unset"<br/>  ],<br/>  "name": null,<br/>  "namespace": null,<br/>  "regex_replace_chars": null,<br/>  "stage": null,<br/>  "tags": {},<br/>  "tenant": null<br/>}</pre> | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Desired number of tasks that need to be running for the service | `number` | `1` | no |
| <a name="input_ecs_cluster_name"></a> [ecs\_cluster\_name](#input\_ecs\_cluster\_name) | Name of the ECS cluster in which the service is deployed | `string` | n/a | yes |
| <a name="input_egress_rules"></a> [egress\_rules](#input\_egress\_rules) | Egress rules for the default security group for the service | <pre>list(object({<br/>    description = string<br/>    from_port   = number<br/>    to_port     = number<br/>    protocol    = optional(string, "-1")<br/><br/>    cidr_blocks      = optional(list(string))<br/>    ipv6_cidr_blocks = optional(list(string))<br/>    prefix_list_ids  = optional(list(string))<br/>    security_groups  = optional(list(string))<br/>    self             = optional(bool)<br/>  }))</pre> | `[]` | no |
| <a name="input_enable_ecs_execute_command"></a> [enable\_ecs\_execute\_command](#input\_enable\_ecs\_execute\_command) | Enables ECS exec to the service and attaches required IAM policy to task role | `bool` | `false` | no |
| <a name="input_execution_role_name"></a> [execution\_role\_name](#input\_execution\_role\_name) | Name for the IAM Role used as the execution role | `string` | n/a | yes |
| <a name="input_force_new_deployment"></a> [force\_new\_deployment](#input\_force\_new\_deployment) | Whether to force a new deployment of the service. This can be used to update the service with a new task definition | `bool` | `false` | no |
| <a name="input_high_traffic_service"></a> [high\_traffic\_service](#input\_high\_traffic\_service) | Whether the service is a high traffic service: >500 requests/second | `bool` | `false` | no |
| <a name="input_ingress_rules"></a> [ingress\_rules](#input\_ingress\_rules) | Ingress rules for the default security group for the service | <pre>list(object({<br/>    description = string<br/>    from_port   = number<br/>    to_port     = number<br/>    protocol    = optional(string, "-1")<br/><br/>    cidr_blocks      = optional(list(string))<br/>    ipv6_cidr_blocks = optional(list(string))<br/>    prefix_list_ids  = optional(list(string))<br/>    security_groups  = optional(list(string))<br/>    self             = optional(bool)<br/>  }))</pre> | `[]` | no |
| <a name="input_load_balancers"></a> [load\_balancers](#input\_load\_balancers) | List of load balancers to attach to the service | <pre>list(object({<br/>    target_group_arn = string<br/>    container_name   = string<br/>    container_port   = number<br/>  }))</pre> | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the ECS service | `string` | n/a | yes |
| <a name="input_platform_version"></a> [platform\_version](#input\_platform\_version) | Platform version for the ECS service | `string` | `"LATEST"` | no |
| <a name="input_scaling"></a> [scaling](#input\_scaling) | Scaling configuration for the service. Enables scaling | <pre>object({<br/>    min_capacity = number<br/>    max_capacity = number<br/>  })</pre> | `null` | no |
| <a name="input_scaling_scheduled"></a> [scaling\_scheduled](#input\_scaling\_scheduled) | Scheduled scaling policies for the service. Enables Scheduled scaling | <pre>map(object({<br/>    schedule     = string<br/>    timezone     = string<br/>    min_capacity = number<br/>    max_capacity = number<br/>  }))</pre> | `null` | no |
| <a name="input_scaling_target"></a> [scaling\_target](#input\_scaling\_target) | Target tracking scaling policies for the service. Enables Target tracking scaling. Predefined metric type must be one of ECSServiceAverageCPUUtilization, ALBRequestCountPerTarget or ECSServiceAverageMemoryUtilization - https://docs.aws.amazon.com/autoscaling/application/APIReference/API_PredefinedMetricSpecification.html | <pre>map(object({<br/>    predefined_metric_type = string<br/>    resource_label         = optional(string)<br/>    target_value           = number<br/>    scale_in_cooldown      = optional(number, 300)<br/>    scale_out_cooldown     = optional(number, 300)<br/>  }))</pre> | `null` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | List of additional security groups to attach to the service | `list(string)` | `[]` | no |
| <a name="input_service_connect_configuration"></a> [service\_connect\_configuration](#input\_service\_connect\_configuration) | Service discovery configuration for the service | <pre>object({<br/>    namespace      = string<br/>    discovery_name = string<br/>    port_name      = string<br/>    client_alias = object({<br/>      dns_name = string<br/>      port     = number<br/>    })<br/>    cloudwatch = optional(object({<br/>      log_group = string<br/>      region    = string<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | List of Subnet ids in which the Service runs | `list(string)` | n/a | yes |
| <a name="input_task_cpu"></a> [task\_cpu](#input\_task\_cpu) | value in cpu units for the task | `number` | n/a | yes |
| <a name="input_task_memory"></a> [task\_memory](#input\_task\_memory) | value in MiB for the task | `number` | n/a | yes |
| <a name="input_task_role_name"></a> [task\_role\_name](#input\_task\_role\_name) | Name for the IAM Role used as the task role | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC in which the service is deployed | `string` | n/a | yes |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | The ARN of the ECS cluster |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the ECS cluster |
| <a name="output_label_context"></a> [label\_context](#output\_label\_context) | Context of the label for subsequent use |
| <a name="output_scaling_target"></a> [scaling\_target](#output\_scaling\_target) | The autoscaling target resource - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target |
| <a name="output_security_group_arn"></a> [security\_group\_arn](#output\_security\_group\_arn) | The ARN of the security group |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | The ID of the security group |
| <a name="output_service_arn"></a> [service\_arn](#output\_service\_arn) | The ARN of the service |
| <a name="output_service_discovery_client_aliases"></a> [service\_discovery\_client\_aliases](#output\_service\_discovery\_client\_aliases) | The service discovery client aliases for the service |
| <a name="output_service_discovery_internal_url"></a> [service\_discovery\_internal\_url](#output\_service\_discovery\_internal\_url) | Base URL for the service internally |
| <a name="output_service_discovery_name"></a> [service\_discovery\_name](#output\_service\_discovery\_name) | The service discovery name for the service |
| <a name="output_service_id"></a> [service\_id](#output\_service\_id) | The ID of the service |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | The name of the service |
| <a name="output_task_definition_arn"></a> [task\_definition\_arn](#output\_task\_definition\_arn) | The ARN of the task definition |
| <a name="output_task_definition_family"></a> [task\_definition\_family](#output\_task\_definition\_family) | The family of the task definition |
| <a name="output_task_definition_id"></a> [task\_definition\_id](#output\_task\_definition\_id) | The ID of the task definition |
<!-- END_TF_DOCS -->
