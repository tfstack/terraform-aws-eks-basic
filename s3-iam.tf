################################################################################
# S3 IAM Roles (IRSA or EKS Pod Identity)
# One IAM role per s3_access entry; each role has scoped S3 permissions.
#
# When using Pod Identity:
# - Requires eks-pod-identity-agent addon in addons
# - One Pod Identity association per (namespace, service_account)
################################################################################

locals {
  s3_access_map = var.enable_s3 ? { for i, a in var.s3_access : "${a.namespace}/${a.service_account}" => a } : {}
}

# IAM assume role policy document for S3 (IRSA) — one per entry
data "aws_iam_policy_document" "s3_assume_role_irsa" {
  for_each = local.s3_access_map

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
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM assume role policy document for S3 (EKS Pod Identity) — shared shape
data "aws_iam_policy_document" "s3_assume_role_pod_identity" {
  count = var.enable_s3 ? 1 : 0

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

# IAM role for S3 (one per s3_access entry)
resource "aws_iam_role" "s3" {
  for_each = local.s3_access_map

  name               = "${var.name}-s3-${replace(replace(each.key, "/", "-"), "_", "-")}-role"
  assume_role_policy = var.s3_identity_type == "pod_identity" ? data.aws_iam_policy_document.s3_assume_role_pod_identity[0].json : data.aws_iam_policy_document.s3_assume_role_irsa[each.key].json

  tags = var.tags

  lifecycle {
    precondition {
      condition = !var.enable_s3 || (
        length(var.s3_access) > 0 &&
        !contains([for a in var.s3_access : a.namespace], "default") &&
        !contains([for a in var.s3_access : a.namespace], "kube-system")
      )
      error_message = "s3_access must be non-empty when enable_s3 is true. Do not use namespace 'default' or 'kube-system'."
    }
  }

  depends_on = [
    aws_iam_openid_connect_provider.oidc_provider
  ]
}

# S3 policy: ListBucket on bucket ARNs; GetObject (and optionally PutObject, DeleteObject) on bucket/*
data "aws_iam_policy_document" "s3" {
  for_each = local.s3_access_map

  # ListBucket requires bucket ARN (no /*)
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      for arn in each.value.bucket_arns : replace(arn, "/*", "")
    ]
  }

  # Object actions require object ARN (bucket/*)
  statement {
    effect = "Allow"
    actions = each.value.read_only ? [
      "s3:GetObject"
      ] : [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      for arn in each.value.bucket_arns : "${replace(arn, "/*", "")}/*"
    ]
  }
}

resource "aws_iam_role_policy" "s3" {
  for_each = local.s3_access_map

  name   = "s3-access"
  role   = aws_iam_role.s3[each.key].name
  policy = data.aws_iam_policy_document.s3[each.key].json
}

# EKS Pod Identity associations for S3 (one per s3_access entry when pod_identity)
resource "aws_eks_pod_identity_association" "s3" {
  for_each = var.enable_s3 && var.s3_identity_type == "pod_identity" ? local.s3_access_map : {}

  cluster_name    = aws_eks_cluster.this.name
  namespace       = each.value.namespace
  service_account = each.value.service_account
  role_arn        = aws_iam_role.s3[each.key].arn
}
