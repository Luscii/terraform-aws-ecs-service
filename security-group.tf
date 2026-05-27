resource "aws_security_group" "this" {
  name        = module.label.id
  description = "Security Group for ${module.label.id}"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = module.label.tags
}

resource "aws_security_group_ingress_rule" "self" {
  security_group_id = aws_security_group.this.id
  description       = "Allow requests from within the Security Group"
  ip_protocol       = "-1"
  self              = true
}

resource "aws_security_group_ingress_rule" "ingress" {
  for_each = var.ingress_rules

  security_group_id = aws_security_group.this.id
  description       = each.value.description
  ip_protocol       = each.value.ip_protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  cidr_blocks       = each.value.cidr_blocks
  ipv6_cidr_blocks  = each.value.ipv6_cidr_blocks
  prefix_list_ids   = each.value.prefix_list_ids
  security_groups   = each.value.security_groups
  self              = each.value.self
}

resource "aws_security_group_egress_rule" "egress" {
  for_each = var.egress_rules

  security_group_id = aws_security_group.this.id
  description       = each.value.description
  ip_protocol       = each.value.ip_protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  cidr_blocks       = each.value.cidr_blocks
  ipv6_cidr_blocks  = each.value.ipv6_cidr_blocks
  prefix_list_ids   = each.value.prefix_list_ids
  security_groups   = each.value.security_groups
  self              = each.value.self
}
