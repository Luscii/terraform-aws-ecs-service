module "container_definitions" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.61.1"

  count = length(var.container_definitions)

  container_name  = var.container_definitions[count.index].name
  container_image = var.container_definitions[count.index].image
  essential       = var.container_definitions[count.index].essential

  container_cpu                = var.container_definitions[count.index].cpu
  container_memory             = var.container_definitions[count.index].memory
  container_memory_reservation = var.container_definitions[count.index].memory_reservation

  port_mappings     = var.container_definitions[count.index].port_mappings
  healthcheck       = var.container_definitions[count.index].healthcheck
  log_configuration = var.container_definitions[count.index].log_configuration

  entrypoint        = var.container_definitions[count.index].entrypoint
  command           = var.container_definitions[count.index].command
  working_directory = var.container_definitions[count.index].working_directory
  ulimits           = var.container_definitions[count.index].ulimits
  user              = var.container_definitions[count.index].user
  start_timeout     = var.container_definitions[count.index].start_timeout
  stop_timeout      = var.container_definitions[count.index].stop_timeout

  environment = var.container_definitions[count.index].environment
  secrets     = var.container_definitions[count.index].secrets

  container_depends_on = var.container_definitions[count.index].depends_on
}
