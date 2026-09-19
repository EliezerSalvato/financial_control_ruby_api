provider "aws" {
  region = var.lightsail.region

  default_tags {
    tags = {
      project     = var.tags.project
      environment = var.tags.environment
      managed_by  = "terraform"
    }
  }
}
