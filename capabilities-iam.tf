# =============================================================================
# EKS Capabilities IAM Roles
# IAM roles required for EKS Capabilities (ACK, KRO, ArgoCD)
# =============================================================================

# ACK Capability Role
data "aws_iam_policy_document" "ack_capability_assume_role" {
  count = var.enable_ack_capability ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["capabilities.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "ack_capability" {
  count = var.enable_ack_capability ? 1 : 0

  name               = var.ack_capability_role_arn != null ? null : "${var.cluster_name}-ack-capability-role"
  name_prefix        = var.ack_capability_role_arn != null ? null : null
  assume_role_policy = data.aws_iam_policy_document.ack_capability_assume_role[0].json
  tags               = var.tags
}

# Attach IAM policies to ACK capability role
resource "aws_iam_role_policy_attachment" "ack_capability" {
  for_each = var.enable_ack_capability ? var.ack_capability_iam_policy_arns : {}

  role       = aws_iam_role.ack_capability[0].name
  policy_arn = each.value
}

# KRO Capability Role
data "aws_iam_policy_document" "kro_capability_assume_role" {
  count = var.enable_kro_capability ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["capabilities.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "kro_capability" {
  count = var.enable_kro_capability ? 1 : 0

  name               = var.kro_capability_role_arn != null ? null : "${var.cluster_name}-kro-capability-role"
  name_prefix        = var.kro_capability_role_arn != null ? null : null
  assume_role_policy = data.aws_iam_policy_document.kro_capability_assume_role[0].json
  tags               = var.tags
}

# Note: KRO capability roles don't require managed policies - AWS manages permissions internally

# ArgoCD Capability Role
data "aws_iam_policy_document" "argocd_capability_assume_role" {
  count = var.enable_argocd_capability ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["capabilities.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "argocd_capability" {
  count = var.enable_argocd_capability ? 1 : 0

  name               = var.argocd_capability_role_arn != null ? null : "${var.cluster_name}-argocd-capability-role"
  name_prefix        = var.argocd_capability_role_arn != null ? null : null
  assume_role_policy = data.aws_iam_policy_document.argocd_capability_assume_role[0].json
  tags               = var.tags
}

# Note: ArgoCD capability roles don't require managed policies - AWS manages permissions internally
# ArgoCD also requires configuration which should be provided via the capability resource
