module "xray_container_definition" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.61.2"

  container_name               = "xray-daemon"
  container_image              = "amazon/aws-xray-daemon:3.x"
  container_cpu                = 128
  container_memory             = 256
  container_memory_reservation = 128
  essential                    = true
  stop_timeout                 = 30

  port_mappings = [
    {
      containerPort : 2000,
      hostPort : 2000,
      protocol : "udp"
      name : "xray"
    }
  ]
}
