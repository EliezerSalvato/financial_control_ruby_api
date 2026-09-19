resource "aws_sesv2_email_identity_mail_from_attributes" "this" {
  email_identity         = aws_sesv2_email_identity.this.email_identity
  mail_from_domain       = var.ses.mail_from_domain
  behavior_on_mx_failure = "USE_DEFAULT_VALUE"
}
