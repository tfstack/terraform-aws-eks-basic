################################################################################
# DynamoDB IAM Roles (IRSA or EKS Pod Identity)
# One IAM role per dynamodb_access entry; each role has scoped DynamoDB permissions.
#
# When using Pod Identity:
# - Requires eks-pod-identity-agent addon in addons
# - One Pod Identity association per (namespace, service_account)
################################################################################

locals {
  dynamodb_access_map = var.enable_dynamodb_access ? { for i, a in var.dynamodb_access : "${a.namespace}/${a.service_account}" => a } : {}
}

# IAM assume role policy document for DynamoDB (IRSA) — one per entry
data "aws_iam_policy_document" "dynamodb_assume_role_irsa" {
  for_each = local.dynamodb_access_map

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

# IAM assume role policy document for DynamoDB (EKS Pod Identity) — shared shape
data "aws_iam_policy_document" "dynamodb_assume_role_pod_identity" {
  count = var.enable_dynamodb_access ? 1 : 0

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

# IAM role for DynamoDB (one per dynamodb_access entry)
resource "aws_iam_role" "dynamodb" {
  for_each = local.dynamodb_access_map

  name               = "${var.name}-dynamodb-${replace(replace(each.key, "/", "-"), "_", "-")}-role"
  assume_role_policy = var.dynamodb_identity_type == "pod_identity" ? data.aws_iam_policy_document.dynamodb_assume_role_pod_identity[0].json : data.aws_iam_policy_document.dynamodb_assume_role_irsa[each.key].json

  tags = var.tags

  lifecycle {
    precondition {
      condition = !var.enable_dynamodb_access || (
        length(var.dynamodb_access) > 0 &&
        !contains([for a in var.dynamodb_access : a.namespace], "default") &&
        !contains([for a in var.dynamodb_access : a.namespace], "kube-system")
      )
      error_message = "dynamodb_access must be non-empty when enable_dynamodb_access is true. Do not use namespace 'default' or 'kube-system'."
    }

    precondition {
      condition     = contains(["read_only", "read_write"], try(each.value.mode, "read_only"))
      error_message = "dynamodb_access.mode must be one of: read_only, read_write."
    }
  }

  depends_on = [
    aws_iam_openid_connect_provider.oidc_provider
  ]
}

data "aws_iam_policy_document" "dynamodb" {
  for_each = local.dynamodb_access_map

  statement {
    effect = "Allow"
    actions = try(each.value.mode, "read_only") == "read_only" ? [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
      "dynamodb:Scan"
      ] : [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:BatchWriteItem"
    ]
    resources = distinct(concat(
      each.value.table_arns,
      [for arn in each.value.table_arns : "${arn}/index/*"]
    ))
  }
}

resource "aws_iam_role_policy" "dynamodb" {
  for_each = local.dynamodb_access_map

  name   = "dynamodb-access"
  role   = aws_iam_role.dynamodb[each.key].name
  policy = data.aws_iam_policy_document.dynamodb[each.key].json
}

# EKS Pod Identity associations for DynamoDB (one per dynamodb_access entry when pod_identity)
resource "aws_eks_pod_identity_association" "dynamodb" {
  for_each = var.enable_dynamodb_access && var.dynamodb_identity_type == "pod_identity" ? local.dynamodb_access_map : {}

  cluster_name    = aws_eks_cluster.this.name
  namespace       = each.value.namespace
  service_account = each.value.service_account
  role_arn        = aws_iam_role.dynamodb[each.key].arn
}

