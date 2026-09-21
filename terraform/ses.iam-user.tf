# Intentionally no aws_iam_access_key: the access key is created out of band
# so secret never enters Terraform state.

# SES sandbox (and SendRawEmail) authorizes sender AND recipient identities as
# IAM resources. Pinning Resource to the domain ARN therefore denies any To:
# address that is not that domain (for example a verified Gmail in sandbox).
# Restrict the From address instead; recipients stay unrestricted here.
data "aws_iam_policy_document" "ses_send" {
  statement {
    sid    = "SendFromVerifiedDomain"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "ses:FromAddress"
      values   = ["*@${var.ses.domain}"]
    }
  }
}

resource "aws_iam_user" "send" {
  name          = var.ses.iam_user_name
  path          = "/"
  force_destroy = true
}

resource "aws_iam_user_policy" "send" {
  name   = "ses-send-only"
  user   = aws_iam_user.send.name
  policy = data.aws_iam_policy_document.ses_send.json
}
