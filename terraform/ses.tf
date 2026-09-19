# Easy DKIM: do not set dkim_signing_attributes (that block is BYODKIM only).
resource "aws_sesv2_email_identity" "this" {
  email_identity = var.ses.domain
}
