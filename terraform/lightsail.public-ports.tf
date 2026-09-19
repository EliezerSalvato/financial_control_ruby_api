resource "aws_lightsail_instance_public_ports" "this" {
  instance_name = aws_lightsail_instance.this.name

  dynamic "port_info" {
    for_each = {
      for port in var.lightsail.public_ports :
      "${port.protocol}-${port.from_port}-${port.to_port}" => port
    }

    content {
      protocol   = port_info.value.protocol
      from_port  = port_info.value.from_port
      to_port    = port_info.value.to_port
      cidrs      = port_info.value.cidrs
      ipv6_cidrs = length(port_info.value.ipv6_cidrs) > 0 ? port_info.value.ipv6_cidrs : null
    }
  }
}
