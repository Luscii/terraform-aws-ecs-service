locals {
  xray_container_definition = {
    name               = "xray-daemon"
    image              = "amazon/aws-xray-daemon:3.x"
    cpu                = 128
    memory             = 256
    memory_reservation = 128
    essential          = true
    stop_timeout       = 30
    port_mappings = [
      {
        containerPort = 2000
        protocol      = "udp"
        name          = "xray"
      }
    ]
  }
