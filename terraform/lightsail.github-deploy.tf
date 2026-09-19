# Intentionally no aws_iam_access_key: the access key is created out of band
# so the secret never enters Terraform state.

data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid    = "TemporarySshAllowlist"
    effect = "Allow"
    actions = [
      "lightsail:OpenInstancePublicPorts",
      "lightsail:CloseInstancePublicPorts",
    ]
    resources = [
      aws_lightsail_instance.this.arn,
    ]
  }
}

resource "aws_iam_user" "github_deploy" {
  name          = var.github_deploy.iam_user_name
  path          = "/"
  force_destroy = true
}

resource "aws_iam_user_policy" "github_deploy" {
  name   = "lightsail-temporary-ssh-allowlist"
  user   = aws_iam_user.github_deploy.name
  policy = data.aws_iam_policy_document.github_deploy.json
}
