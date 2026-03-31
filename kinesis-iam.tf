################################################################################
# Kinesis IAM Roles (IRSA or EKS Pod Identity)
# One IAM role per kinesis_access entry; each role has scoped Kinesis permissions.
#
# When using Pod Identity:
# - Requires eks-pod-identity-agent addon in addons
# - One Pod Identity association per (namespace, service_account)
################################################################################

locals {
  kinesis_access_map = var.enable_kinesis_access ? { for i, a in var.kinesis_access : "${a.namespace}/${a.service_account}" => a } : {}
}

# IAM assume role policy document for Kinesis (IRSA) — one per entry
data "aws_iam_policy_document" "kinesis_assume_role_irsa" {
  for_each = local.kinesis_access_map

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

# IAM assume role policy document for Kinesis (EKS Pod Identity) — shared shape
data "aws_iam_policy_document" "kinesis_assume_role_pod_identity" {
  count = var.enable_kinesis_access ? 1 : 0

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

# IAM role for Kinesis (one per kinesis_access entry)
resource "aws_iam_role" "kinesis" {
  for_each = local.kinesis_access_map

  name               = "${var.name}-kinesis-${replace(replace(each.key, "/", "-"), "_", "-")}-role"
  assume_role_policy = var.kinesis_identity_type == "pod_identity" ? data.aws_iam_policy_document.kinesis_assume_role_pod_identity[0].json : data.aws_iam_policy_document.kinesis_assume_role_irsa[each.key].json

  tags = var.tags

  lifecycle {
    precondition {
      condition = !var.enable_kinesis_access || (
        length(var.kinesis_access) > 0 &&
        !contains([for a in var.kinesis_access : a.namespace], "default") &&
        !contains([for a in var.kinesis_access : a.namespace], "kube-system")
      )
      error_message = "kinesis_access must be non-empty when enable_kinesis_access is true. Do not use namespace 'default' or 'kube-system'."
    }

    precondition {
      condition     = contains(["consumer", "read_only"], try(each.value.mode, "consumer"))
      error_message = "kinesis_access.mode must be one of: consumer, read_only."
    }
  }

  depends_on = [
    aws_iam_openid_connect_provider.oidc_provider
  ]
}

data "aws_iam_policy_document" "kinesis" {
  for_each = local.kinesis_access_map

  statement {
    effect = "Allow"
    actions = try(each.value.mode, "consumer") == "read_only" ? [
      "kinesis:DescribeStreamSummary",
      "kinesis:ListShards"
      ] : [
      "kinesis:DescribeStreamSummary",
      "kinesis:ListShards",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords"
    ]
    resources = each.value.stream_arns
  }
}

resource "aws_iam_role_policy" "kinesis" {
  for_each = local.kinesis_access_map

  name   = "kinesis-access"
  role   = aws_iam_role.kinesis[each.key].name
  policy = data.aws_iam_policy_document.kinesis[each.key].json
}

# EKS Pod Identity associations for Kinesis (one per kinesis_access entry when pod_identity)
resource "aws_eks_pod_identity_association" "kinesis" {
  for_each = var.enable_kinesis_access && var.kinesis_identity_type == "pod_identity" ? local.kinesis_access_map : {}

  cluster_name    = aws_eks_cluster.this.name
  namespace       = each.value.namespace
  service_account = each.value.service_account
  role_arn        = aws_iam_role.kinesis[each.key].arn
}

