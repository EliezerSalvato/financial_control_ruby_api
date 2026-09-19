locals {
  ssh_public_key = trimspace(var.access.ssh_public_key_path) != "" ? file(var.access.ssh_public_key_path) : var.access.ssh_public_key
}

# Supplying public_key imports an existing local key. Terraform then does not
# generate a private key, so state will not contain the private_key attribute.
resource "aws_lightsail_key_pair" "this" {
  name       = var.lightsail.key_pair_name
  public_key = local.ssh_public_key
}
