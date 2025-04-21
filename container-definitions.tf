locals {
  container_definitions = concat(var.container_definitions, var.add_xray_container ? [local.xray_container_definition] : [])
}

module "container_definitions" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.61.2"

  count = length(local.container_definitions)

  container_name = local.container_definitions[count.index].name
  container_image = (lookup(local.container_definitions[count.index], "pull_cache_prefix", "") == ""
    ? local.container_definitions[count.index].image
    : "${lookup(local.pull_cache_rule_urls, local.container_definitions[count.index].pull_cache_prefix, "")}${local.container_definitions[count.index].image}"
  )
  essential = local.container_definitions[count.index].essential

  container_cpu                = local.container_definitions[count.index].cpu
  container_memory             = contains(keys(local.container_definitions[count.index]), "memory") ? local.container_definitions[count.index].memory : null
  container_memory_reservation = contains(keys(local.container_definitions[count.index]), "memory_reservation") ? local.container_definitions[count.index].memory_reservation : null

  port_mappings     = contains(keys(local.container_definitions[count.index]), "port_mappings") ? local.container_definitions[count.index].port_mappings : null
  healthcheck       = contains(keys(local.container_definitions[count.index]), "healthcheck") ? local.container_definitions[count.index].healthcheck : null
  log_configuration = contains(keys(local.container_definitions[count.index]), "log_configuration") ? local.container_definitions[count.index].log_configuration : null

  entrypoint        = contains(keys(local.container_definitions[count.index]), "entrypoint") ? local.container_definitions[count.index].entrypoint : null
  command           = contains(keys(local.container_definitions[count.index]), "command") ? local.container_definitions[count.index].command : null
  working_directory = contains(keys(local.container_definitions[count.index]), "working_directory") ? local.container_definitions[count.index].working_directory : null
  ulimits           = contains(keys(local.container_definitions[count.index]), "ulimits") ? local.container_definitions[count.index].ulimits : null
  user              = contains(keys(local.container_definitions[count.index]), "user") ? local.container_definitions[count.index].user : null
  start_timeout     = contains(keys(local.container_definitions[count.index]), "start_time") ? local.container_definitions[count.index].start_timeout : null
  stop_timeout      = contains(keys(local.container_definitions[count.index]), "stop_time") ? local.container_definitions[count.index].stop_timeout : null

  environment = contains(keys(local.container_definitions[count.index]), "environment") ? local.container_definitions[count.index].environment : null
  secrets     = contains(keys(local.container_definitions[count.index]), "secrets") ? local.container_definitions[count.index].secrets : null

  container_depends_on = contains(keys(local.container_definitions[count.index]), "depends_on") ? local.container_definitions[count.index].depends_on : null
}
