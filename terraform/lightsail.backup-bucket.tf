resource "aws_lightsail_bucket" "this" {
  name      = var.lightsail.bucket_name
  bundle_id = var.lightsail.bucket_bundle_id
}

resource "aws_lightsail_bucket_resource_access" "this" {
  bucket_name   = aws_lightsail_bucket.this.name
  resource_name = aws_lightsail_instance.this.name
}
