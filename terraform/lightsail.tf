# Lightsail user_data only accepts a single-line string. The bootstrap script
# is stored as a file and piped through base64 so it can stay readable.
locals {
  lightsail_user_data = "echo '${base64encode(file("${path.module}/../deploy/scripts/bootstrap.sh"))}' | base64 -d | bash"
}

resource "aws_lightsail_instance" "this" {
  name              = var.lightsail.instance_name
  availability_zone = var.lightsail.availability_zone
  blueprint_id      = var.lightsail.blueprint_id
  bundle_id         = var.lightsail.bundle_id
  ip_address_type   = var.lightsail.ip_address_type
  key_pair_name     = aws_lightsail_key_pair.this.name
  user_data         = local.lightsail_user_data

  add_on {
    type          = "AutoSnapshot"
    snapshot_time = var.lightsail.auto_snapshot_time
    status        = "Enabled"
  }

  # Launch scripts do not re-run after create. Ignore so bootstrap.sh edits
  # do not replace the instance.
  lifecycle {
    ignore_changes = [user_data]
  }
}
