################################################################################
# Addon IAM Roles (IRSA)
# IAM roles required for EKS addons that need service account permissions
################################################################################

# Service account names for addons that require IRSA
locals {
  addon_service_accounts = {
    "aws-ebs-csi-driver" = {
      namespace = "kube-system"
      name      = "ebs-csi-controller-sa"
    }
  }
}

# IAM assume role policy documents for addons
data "aws_iam_policy_document" "addon_assume_role" {
  for_each = {
    for k, v in var.addons : k => v
    if contains(keys(local.addon_service_accounts), k) && try(v.service_account_role_arn, null) == null
  }

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
      values   = ["system:serviceaccount:${local.addon_service_accounts[each.key].namespace}:${local.addon_service_accounts[each.key].name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM roles for addons (only created when service_account_role_arn is not provided)
resource "aws_iam_role" "addon" {
  for_each = {
    for k, v in var.addons : k => v
    if contains(keys(local.addon_service_accounts), k) && try(v.service_account_role_arn, null) == null
  }

  name               = "${var.name}-${replace(each.key, "-", "_")}-addon-role"
  assume_role_policy = data.aws_iam_policy_document.addon_assume_role[each.key].json

  tags = var.tags

  depends_on = [
    aws_iam_openid_connect_provider.oidc_provider
  ]
}

# Attach AWS managed policy for EBS CSI driver
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  for_each = {
    for k, v in var.addons : k => v
    if k == "aws-ebs-csi-driver" && try(v.service_account_role_arn, null) == null
  }

  role       = aws_iam_role.addon[each.key].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
