################################################################################
# Addon IAM Roles (IRSA or Pod Identity)
# IAM roles required for EKS addons that need service account permissions
################################################################################

# Service account names for addons that require IRSA (when addon_identity_type = "irsa")
locals {
  addon_service_accounts = {
    "aws-ebs-csi-driver" = {
      namespace = "kube-system"
      name      = "ebs-csi-controller-sa"
    }
  }

  # Addons that get a module-created role: from local.addon_service_accounts (IRSA) or var.addon_service_accounts (Pod Identity)
  addon_role_config = var.addon_identity_type == "irsa" ? {
    for k, v in var.addons : k => local.addon_service_accounts[k]
    if contains(keys(local.addon_service_accounts), k) && try(v.service_account_role_arn, null) == null
    } : {
    for k, v in var.addons : k => var.addon_service_accounts[k]
    if contains(keys(var.addon_service_accounts), k) && try(v.service_account_role_arn, null) == null
  }
}

# IAM assume role policy documents for addons (IRSA)
data "aws_iam_policy_document" "addon_assume_role" {
  for_each = {
    for k, v in local.addon_role_config : k => v
    if var.addon_identity_type == "irsa"
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
      values   = ["system:serviceaccount:${local.addon_role_config[each.key].namespace}:${local.addon_role_config[each.key].name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM assume role policy documents for addons (EKS Pod Identity)
data "aws_iam_policy_document" "addon_assume_role_pod_identity" {
  for_each = {
    for k, v in local.addon_role_config : k => v
    if var.addon_identity_type == "pod_identity"
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

# IAM roles for addons (IRSA or Pod Identity per addon_identity_type)
resource "aws_iam_role" "addon" {
  for_each = local.addon_role_config

  name               = "${var.name}-${replace(each.key, "-", "_")}-addon-role"
  assume_role_policy = var.addon_identity_type == "pod_identity" ? data.aws_iam_policy_document.addon_assume_role_pod_identity[each.key].json : data.aws_iam_policy_document.addon_assume_role[each.key].json

  tags = var.tags

  depends_on = [
    aws_iam_openid_connect_provider.oidc_provider
  ]
}

# EKS Pod Identity associations for addons (when addon_identity_type = "pod_identity")
resource "aws_eks_pod_identity_association" "addon" {
  for_each = {
    for k, v in local.addon_role_config : k => v
    if var.addon_identity_type == "pod_identity"
  }

  cluster_name    = aws_eks_cluster.this.name
  namespace       = each.value.namespace
  service_account = each.value.name
  role_arn        = aws_iam_role.addon[each.key].arn
}

# Attach AWS managed policy for EBS CSI driver
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  for_each = {
    for k, v in local.addon_role_config : k => v
    if k == "aws-ebs-csi-driver"
  }

  role       = aws_iam_role.addon[each.key].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
