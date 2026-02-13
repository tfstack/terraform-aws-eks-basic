################################################################################
# ExternalDNS IAM Role (IRSA)
# IAM role required for ExternalDNS to manage Route53 DNS records
################################################################################

# IAM assume role policy document for ExternalDNS
data "aws_iam_policy_document" "external_dns_assume_role" {
  count = var.enable_external_dns ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc_provider[0].arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:external-dns"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM role for ExternalDNS
resource "aws_iam_role" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name               = "${var.name}-external-dns-role"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role[0].json

  tags = var.tags

  depends_on = [
    aws_iam_openid_connect_provider.oidc_provider
  ]
}

# IAM policy document for ExternalDNS Route53 permissions
data "aws_iam_policy_document" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  statement {
    sid    = "AllowChangeResourceRecordSets"
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets"
    ]
    resources = ["arn:${data.aws_partition.current.partition}:route53:::hostedzone/*"]
  }

  statement {
    sid    = "AllowListResourceRecordSets"
    effect = "Allow"
    actions = [
      "route53:ListResourceRecordSets"
    ]
    resources = ["arn:${data.aws_partition.current.partition}:route53:::hostedzone/*"]
  }

  statement {
    sid    = "AllowListHostedZones"
    effect = "Allow"
    actions = [
      "route53:ListHostedZones"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowListTagsForResource"
    effect = "Allow"
    actions = [
      "route53:ListTagsForResource"
    ]
    resources = ["arn:${data.aws_partition.current.partition}:route53:::hostedzone/*"]
  }

  statement {
    sid    = "AllowGetChange"
    effect = "Allow"
    actions = [
      "route53:GetChange"
    ]
    resources = ["arn:${data.aws_partition.current.partition}:route53:::change/*"]
  }
}

# IAM policy for ExternalDNS
resource "aws_iam_role_policy" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name   = "${var.name}-external-dns-policy"
  role   = aws_iam_role.external_dns[0].id
  policy = data.aws_iam_policy_document.external_dns[0].json
}
