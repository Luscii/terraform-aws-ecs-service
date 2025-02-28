module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  context = var.context
  name    = var.name
}

# module "path" {
#   source  = "cloudposse/label/null"
#   version = "0.25.0"

#   context = module.label.context
#   delimiter = var.path_delimiter
# }

data "aws_ecs_cluster" "this" {
  cluster_name = var.ecs_cluster_name
}
