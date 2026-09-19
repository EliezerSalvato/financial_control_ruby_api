# Intentionally no aws_iam_access_key: the access key is created out of band
# so secret never enters Terraform state.

data "aws_iam_policy_document" "ses_send" {
  statement {
    sid    = "SendFromVerifiedDomain"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = [
      aws_sesv2_email_identity.this.arn,
    ]
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
