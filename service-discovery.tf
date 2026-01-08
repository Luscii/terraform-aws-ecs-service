locals {
  # Determine if automated service discovery should be created
  create_service_discovery = length(var.service_discovery_dns_namespace_ids) > 0 && var.service_connect_configuration != null

  # Extract service name from service_connect_configuration
  service_discovery_name = local.create_service_discovery ? var.service_connect_configuration.client_alias.dns_name : null

  # Find the container that has the service connect port
  service_connect_container = local.create_service_discovery ? (
    one([for name, port_names in local.container_port_names :
      name if contains(port_names, var.service_connect_configuration.port_name)
    ])
  ) : null

  # Combine automated and manual service registries
  all_service_registries = concat(
    var.service_registries != null ? [var.service_registries] : [],
    [for service in aws_service_discovery_service.this : {
      registry_arn   = service.arn
      container_name = local.service_connect_container
    }]
  )
}

# Create Cloud Map services for each DNS namespace
resource "aws_service_discovery_service" "this" {
  for_each = toset(var.service_discovery_dns_namespace_ids)

  name = local.service_discovery_name

  dns_config {
    namespace_id = each.value

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = module.label.tags
}
