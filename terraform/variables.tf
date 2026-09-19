variable "lightsail" {
  description = "Lightsail instance, networking, snapshot, and backup-bucket settings."
  type = object({
    region             = string
    availability_zone  = string
    bundle_id          = string
    blueprint_id       = string
    instance_name      = string
    key_pair_name      = string
    static_ip_name     = string
    ip_address_type    = string
    auto_snapshot_time = string
    bucket_name        = string
    bucket_bundle_id   = string
    public_ports = list(object({
      from_port  = number
      to_port    = number
      protocol   = string
      cidrs      = list(string)
      ipv6_cidrs = list(string)
    }))
  })
  nullable = false

  validation {
    condition     = can(regex("^\\d{2}:00$", var.lightsail.auto_snapshot_time))
    error_message = "auto_snapshot_time must be an hourly UTC value in HH:00 format."
  }

  validation {
    condition = length(toset([
      var.lightsail.instance_name,
      var.lightsail.key_pair_name,
      var.lightsail.static_ip_name,
    ])) == 3
    error_message = "Lightsail instance_name, key_pair_name, and static_ip_name must be unique; names are regional across all Lightsail resource types."
  }

  validation {
    condition     = length(var.lightsail.public_ports) == 3
    error_message = "Exactly three public port_info blocks are required (22, 80, and 443)."
  }

  validation {
    condition = alltrue([
      for port in var.lightsail.public_ports : !contains([25, 3000, 465, 587, 5432], port.from_port) && !contains([25, 3000, 465, 587, 5432], port.to_port)
    ])
    error_message = "Do not open inbound 25, 3000, 465, 587, or 5432 on the Lightsail firewall."
  }

  validation {
    condition = anytrue([
      for port in var.lightsail.public_ports :
      port.from_port == 22 && port.to_port == 22 && port.protocol == "tcp" && length(port.ipv6_cidrs) == 0 && !contains(port.cidrs, "0.0.0.0/0")
    ])
    error_message = "Port 22 must be IPv4 source-restricted and must not open IPv6."
  }

  validation {
    condition = alltrue([
      for port in var.lightsail.public_ports :
      !contains([80, 443], port.from_port) || (contains(port.cidrs, "0.0.0.0/0") && contains(port.ipv6_cidrs, "::/0"))
    ])
    error_message = "Ports 80 and 443 must be open on IPv4 (0.0.0.0/0) and IPv6 (::/0) for Let's Encrypt HTTP-01 and HTTPS."
  }
}

variable "access" {
  description = "Operator SSH public key used by aws_lightsail_key_pair. Paste the public key material, or set ssh_public_key_path to a local .pub file. Never supply a private key."
  type = object({
    ssh_public_key      = string
    ssh_public_key_path = optional(string, "")
  })
  nullable = false

  validation {
    condition = (
      trimspace(var.access.ssh_public_key_path) != "" ||
      (
        var.access.ssh_public_key != "CHANGE_ME" &&
        can(regex("^(ssh-(ed25519|rsa)|ecdsa-sha2-nistp256) ", var.access.ssh_public_key))
      )
    )
    error_message = "Supply an existing SSH public key (ssh-ed25519, ssh-rsa, or ecdsa-sha2-nistp256) or ssh_public_key_path. Never paste a private key."
  }
}

variable "ses" {
  description = "Amazon SES domain identity and send-only IAM user used for the SES v2 API."
  type = object({
    domain           = string
    mail_from_domain = string
    iam_user_name    = string
  })
  nullable = false

  validation {
    condition     = !strcontains(var.ses.domain, "CHANGE_ME") && var.ses.domain != "example.com"
    error_message = "Set ses.domain to the production domain identity before apply."
  }

  validation {
    condition     = endswith(var.ses.mail_from_domain, ".${var.ses.domain}")
    error_message = "ses.mail_from_domain must be a subdomain of ses.domain (for example bounce.example.com)."
  }
}

variable "github_deploy" {
  description = "IAM user used by GitHub Actions to temporarily allowlist the runner IPv4 on Lightsail SSH. Create the access key out of band so the secret never enters Terraform state."
  type = object({
    iam_user_name = string
  })
  nullable = false

  validation {
    condition     = length(trimspace(var.github_deploy.iam_user_name)) > 0 && !strcontains(var.github_deploy.iam_user_name, "CHANGE_ME")
    error_message = "Set github_deploy.iam_user_name to a non-empty IAM user name."
  }
}

variable "tags" {
  description = "Resource tags merged into the provider default_tags block (managed_by is fixed in providers.tf)."
  type = object({
    project     = string
    environment = string
  })
  nullable = false
}
