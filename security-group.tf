resource "aws_security_group" "this" {
  name        = module.label.id
  description = "Security Group for ${module.label.id}"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = module.label.tags
}

resource "aws_vpc_security_group_ingress_rule" "self" {
  security_group_id            = aws_security_group.this.id
  description                  = "Allow requests from within the Security Group"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.this.id
}

resource "aws_vpc_security_group_ingress_rule" "ingress" {
  for_each = { for idx, rule in var.ingress_rules : idx => rule }

  security_group_id            = aws_security_group.this.id
  description                  = each.value.description
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  cidr_ipv4                    = each.value.cidr_blocks == null ? null : one(each.value.cidr_blocks)
  cidr_ipv6                    = each.value.ipv6_cidr_blocks == null ? null : one(each.value.ipv6_cidr_blocks)
  prefix_list_id               = each.value.prefix_list_ids == null ? null : one(each.value.prefix_list_ids)
  referenced_security_group_id = each.value.security_groups == null ? null : one(each.value.security_groups)
}

resource "aws_vpc_security_group_egress_rule" "egress" {
  for_each = { for idx, rule in var.egress_rules : idx => rule }

  security_group_id            = aws_security_group.this.id
  description                  = each.value.description
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  cidr_ipv4                    = each.value.cidr_blocks == null ? null : one(each.value.cidr_blocks)
  cidr_ipv6                    = each.value.ipv6_cidr_blocks == null ? null : one(each.value.ipv6_cidr_blocks)
  prefix_list_id               = each.value.prefix_list_ids == null ? null : one(each.value.prefix_list_ids)
  referenced_security_group_id = each.value.security_groups == null ? null : one(each.value.security_groups)
}
