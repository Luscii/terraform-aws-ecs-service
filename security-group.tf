resource "aws_security_group" "this" {
  name        = module.label.id
  description = "Security Group for ${module.label.id}"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow requests from within the Security Group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  dynamic "ingress" {
    for_each = var.ingress_rules

    content {
      description = ingress.value.description

      from_port = ingress.value.from_port
      to_port   = ingress.value.to_port
      protocol  = ingress.value.protocol

      cidr_blocks      = ingress.value.cidr_blocks
      ipv6_cidr_blocks = ingress.value.ipv6_cidr_blocks
      prefix_list_ids  = ingress.value.prefix_list_ids
      security_groups  = ingress.value.security_groups
      self             = ingress.value.self
    }
  }

  dynamic "egress" {
    for_each = var.egress_rules

    content {
      description = egress.value.description

      from_port = egress.value.from_port
      to_port   = egress.value.to_port
      protocol  = egress.value.protocol

      cidr_blocks      = egress.value.cidr_blocks
      ipv6_cidr_blocks = egress.value.ipv6_cidr_blocks
      prefix_list_ids  = egress.value.prefix_list_ids
      security_groups  = egress.value.security_groups
      self             = egress.value.self
    }
  }
}
