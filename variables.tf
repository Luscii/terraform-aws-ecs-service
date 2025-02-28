variable "context" {
  type = any
  default = {
    enabled             = true
    namespace           = null
    tenant              = null
    environment         = null
    stage               = null
    name                = null
    delimiter           = null
    attributes          = []
    tags                = {}
    additional_tag_map  = {}
    regex_replace_chars = null
    label_order         = []
    id_length_limit     = null
    label_key_case      = null
    label_value_case    = null
    descriptor_formats  = {}
    # Note: we have to use [] instead of null for unset lists due to
    # https://github.com/hashicorp/terraform/issues/28137
    # which was not fixed until Terraform 1.0.0,
    # but we want the default to be all the labels in `label_order`
    # and we want users to be able to prevent all tag generation
    # by setting `labels_as_tags` to `[]`, so we need
    # a different sentinel to indicate "default"
    labels_as_tags = ["unset"]
  }
  description = <<-EOT
    Single object for setting entire context at once.
    See description of individual variables for details.
    Leave string and numeric variables as `null` to use default value.
    Individual variable settings (non-null) override settings in context object,
    except for attributes, tags, and additional_tag_map, which are merged.
  EOT

  validation {
    condition     = lookup(var.context, "label_key_case", null) == null ? true : contains(["lower", "title", "upper"], var.context["label_key_case"])
    error_message = "Allowed values: `lower`, `title`, `upper`."
  }

  validation {
    condition     = lookup(var.context, "label_value_case", null) == null ? true : contains(["lower", "title", "upper", "none"], var.context["label_value_case"])
    error_message = "Allowed values: `lower`, `title`, `upper`, `none`."
  }
}

variable "name" {
  type        = string
  description = "Name of the ECS service"
}


variable "task_cpu" {
  type        = number
  description = "value in cpu units for the task"

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.task_cpu)
    error_message = "Task CPU must be one of 256, 512, 1024, 2048, 4096, 8192, 16384"
  }
}

variable "task_memory" {
  type        = number
  description = "value in MiB for the task"
}

variable "container_definitions" {
  type = list(object({
    json_map_encoded                = string
    json_map_encoded_list           = string
    json_map_object                 = any
    sensitive_json_map_encoded      = string
    sensitive_json_map_encoded_list = string
    sensitive_json_map_object       = any
  }))
  description = "List of container definitions, accepts the output of the module https://github.com/cloudposse/terraform-aws-ecs-container-definition"
}

variable "task_role_arn" {
  type        = string
  description = "Arn for the IAM Role used as the task role"

  validation {
    condition     = can(regex("^arn:aws:iam::[[:digit:]]{12}:role/.+", var.task_role_arn))
    error_message = "Must be a valid AWS IAM role ARN."
  }
}

variable "execution_role_arn" {
  type        = string
  description = "Arn for the IAM Role used as the execution role"

  validation {
    condition     = can(regex("^arn:aws:iam::[[:digit:]]{12}:role/.+", var.execution_role_arn))
    error_message = "Must be a valid AWS IAM role ARN."
  }
}

variable "enable_ecs_execute_command" {
  type        = bool
  description = "Enables ECS exec to the service and attaches required IAM policy to task role"
  default     = false
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC in which the service is deployed"
}

variable "ecs_cluster_name" {
  type        = string
  description = "Name of the ECS cluster in which the service is deployed"
}

variable "desired_count" {
  type        = number
  description = "Desired number of tasks that need to be running for the service"
  default     = 1
}

variable "subnets" {
  type        = list(string)
  description = "List of Subnet ids in which the Service runs"
}

variable "assign_public_ip" {
  type        = bool
  description = "Whether the service needs a public ip"
  default     = false
}

variable "high_traffic_service" {
  type        = bool
  description = "Whether the service is a high traffic service: >500 requests/second"
  default     = false

}

variable "service_connect_configuration" {
  type = object({
    namespace      = string
    discovery_name = string
    port_name      = string
    client_alias = object({
      dns_name = string
      port     = number
    })
    cloudwatch = optional(object({
      log_group = string
      region    = string
    }))
  })
  description = "Service discovery configuration for the service"
}

variable "ingress_rules" {
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = optional(string, "-1")

    cidr_blocks      = optional(list(string))
    ipv6_cidr_blocks = optional(list(string))
    prefix_list_ids  = optional(list(string))
    security_groups  = optional(list(string))
    self             = optional(bool)
  }))
  description = "Ingress rules for the default security group for the service"
  default     = []
}

variable "egress_rules" {
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = optional(string, "-1")

    cidr_blocks      = optional(list(string))
    ipv6_cidr_blocks = optional(list(string))
    prefix_list_ids  = optional(list(string))
    security_groups  = optional(list(string))
    self             = optional(bool)
  }))
  description = "Egress rules for the default security group for the service"
  default     = []
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of additional security groups to attach to the service"
  default     = []
}

variable "platform_version" {
  type        = string
  description = "Platform version for the ECS service"
  default     = "LATEST"
}

variable "force_new_deployment" {
  type        = bool
  description = "Whether to force a new deployment of the service. This can be used to update the service with a new task definition"
  default     = false
}

variable "load_balancers" {
  type = list(object({
    target_group_arn = string
    container_name   = string
    container_port   = number
  }))
  description = "List of load balancers to attach to the service"
  default     = []
}

variable "scaling" {
  type = object({
    min_capacity = number
    max_capacity = number
  })
  description = "Scaling configuration for the service. Enables scaling"
  default     = null
}

variable "scaling_scheduled" {
  type = map(object({
    schedule     = string
    timezone     = string
    min_capacity = number
    max_capacity = number
  }))
  description = "Scheduled scaling policies for the service. Enables Scheduled scaling"
  default     = null
}

variable "scaling_target" {
  type = map(object({
    predefined_metric_specification = string
    resource_label                  = optional(string)
    target_value                    = number
    scale_in_cooldown               = number
    scale_out_cooldown              = number
  }))
  description = "Target tracking scaling policies for the service. Enables Target tracking scaling. Predefined metric type must be one of ECSServiceAverageCPUUtilization, ALBRequestCountPerTarget or ECSServiceAverageMemoryUtilization - https://docs.aws.amazon.com/autoscaling/application/APIReference/API_PredefinedMetricSpecification.html"
  default     = null

  validation {
    condition     = var.scaling_target == null ? true : alltrue([for policy in var.scaling_target : contains(["ECSServiceAverageCPUUtilization", "ALBRequestCountPerTarget", "ECSServiceAverageMemoryUtilization"], policy.predefined_metric_specification)])
    error_message = "Predefined metric type should be one of ECSServiceAverageCPUUtilization or ECSServiceAverageMemoryUtilization"
  }

  validation {
    condition     = var.scaling_target == null ? true : alltrue([for policy in var.scaling_target : (policy.predefined_metric_type == "ALBRequestCountPerTarget" && regex("^app/.+/[[:alnum:]]+/targetgroup/.+/[[:alnum:]]+", policy.resource_label)) || true])
    error_message = "When predefined metric type is ALBRequestCountPerTarget, resource_label must be set and following the format defined on https://docs.aws.amazon.com/autoscaling/ec2/APIReference/API_PredefinedMetricSpecification.html"
  }
}
