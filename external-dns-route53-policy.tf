################################################################################
# Shared Route53 policy for ExternalDNS (Helm path + EKS external-dns add-on)
################################################################################

locals {
  external_dns_route53_hosted_zone_arns = (
    var.external_dns_hosted_zone_arns != null && length(var.external_dns_hosted_zone_arns) > 0
    ? var.external_dns_hosted_zone_arns
    : ["arn:${data.aws_partition.current.partition}:route53:::hostedzone/*"]
  )
}

data "aws_iam_policy_document" "external_dns_route53" {
  statement {
    sid    = "AllowChangeResourceRecordSets"
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets"
    ]
    resources = local.external_dns_route53_hosted_zone_arns
  }

  statement {
    sid    = "AllowListResourceRecordSets"
    effect = "Allow"
    actions = [
      "route53:ListResourceRecordSets"
    ]
    resources = local.external_dns_route53_hosted_zone_arns
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
    resources = local.external_dns_route53_hosted_zone_arns
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
