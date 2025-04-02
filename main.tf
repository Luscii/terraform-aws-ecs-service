module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  context = var.context
  name    = var.name
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ecs_cluster" "this" {
  cluster_name = var.ecs_cluster_name
}
