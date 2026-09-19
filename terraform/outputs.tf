output "lightsail_static_ip_ip_address" {
  description = "Public IPv4 address of the Lightsail static IP. Point the API DNS A record here."
  value       = aws_lightsail_static_ip.this.ip_address
}

output "lightsail_instance_ipv6_addresses" {
  description = "IPv6 addresses of the Lightsail instance. Point the API DNS AAAA record at the first address."
  value       = aws_lightsail_instance.this.ipv6_addresses
}

output "lightsail_instance_name" {
  description = "Name of the Lightsail instance."
  value       = aws_lightsail_instance.this.name
}

output "lightsail_bucket_url" {
  description = "URL of the Lightsail backup bucket."
  value       = aws_lightsail_bucket.this.url
}

output "lightsail_bucket_name" {
  description = "Name of the Lightsail backup bucket used by the host pg_dump script."
  value       = aws_lightsail_bucket.this.name
}

output "sesv2_email_identity_arn" {
  description = "ARN of the SESv2 domain identity."
  value       = aws_sesv2_email_identity.this.arn
}

output "sesv2_email_identity_dkim_tokens" {
  description = "Easy DKIM tokens. Publish each as <token>._domainkey.<domain> CNAME to <token>.dkim.amazonses.com."
  value       = try(aws_sesv2_email_identity.this.dkim_signing_attributes[0].tokens, [])
}

output "send_iam_user_name" {
  description = "Send-only IAM user for the SES v2 API. Create the access key out of band so the secret never enters Terraform state."
  value       = aws_iam_user.send.name
}

output "dns_records" {
  description = "Copy-paste DNS records for the current DNS provider. Terraform does not create a hosted zone."
  value       = <<-EOT
    A     api.${var.ses.domain}  ${aws_lightsail_static_ip.this.ip_address}
    AAAA  api.${var.ses.domain}  ${try(aws_lightsail_instance.this.ipv6_addresses[0], "<no-ipv6>")}
    %{for token in try(aws_sesv2_email_identity.this.dkim_signing_attributes[0].tokens, [])~}
    CNAME ${token}._domainkey.${var.ses.domain}  ${token}.dkim.amazonses.com
    %{endfor~}
    MX    ${var.ses.mail_from_domain}  10 feedback-smtp.${var.lightsail.region}.amazonses.com
    TXT   ${var.ses.mail_from_domain}  "v=spf1 include:amazonses.com ~all"
    TXT   _dmarc.${var.ses.domain}  "v=DMARC1; p=none; rua=mailto:dmarc@${var.ses.domain}"
    Apex SPF: add include:amazonses.com to the existing TXT on ${var.ses.domain}. Do not create a second SPF TXT.
    Do not point vue.${var.ses.domain} at this Lightsail IP.
  EOT
}
