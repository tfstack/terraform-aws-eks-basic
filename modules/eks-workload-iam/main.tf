################################################################################
# eks-workload-iam
# Generic per-SA workload IAM: one IAM role + trust policy (IRSA or Pod Identity)
# + caller-supplied permissions + optional Pod Identity association.
#
# Usage pattern:
#   One module instance per (namespace, service_account) pair.
#   The caller owns the IAM policy document (policy_json) so the module stays
#   AWS-service-agnostic. The caller also composes a unique role_name.
#
# IRSA vs Pod Identity:
#   irsa        — OIDC Web Identity; Fargate-compatible; pass oidc_provider_arn + oidc_issuer_url.
#   pod_identity — EKS Pod Identity; requires eks-pod-identity-agent addon; not on Fargate.
################################################################################

data "aws_partition" "current" {}

# ── IRSA trust policy ────────────────────────────────────────────────────────

data "aws_iam_policy_document" "trust_irsa" {
  count = var.identity_type == "irsa" ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ── Pod Identity trust policy ────────────────────────────────────────────────

data "aws_iam_policy_document" "trust_pod_identity" {
  count = var.identity_type == "pod_identity" ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
  }
}

# ── IAM role ─────────────────────────────────────────────────────────────────

resource "aws_iam_role" "this" {
  name = var.role_name

  assume_role_policy = var.identity_type == "pod_identity" ? (
    data.aws_iam_policy_document.trust_pod_identity[0].json
    ) : (
    data.aws_iam_policy_document.trust_irsa[0].json
  )

  tags = var.tags

  lifecycle {
    precondition {
      condition     = !contains(["", "default", "kube-system"], var.namespace)
      error_message = "namespace must not be empty, 'default', or 'kube-system'."
    }

    precondition {
      condition     = var.identity_type != "irsa" || (var.oidc_provider_arn != null && var.oidc_issuer_url != null)
      error_message = "oidc_provider_arn and oidc_issuer_url are required when identity_type = 'irsa'."
    }

    precondition {
      condition     = var.policy_json != null || length(var.managed_policy_arns) > 0
      error_message = "At least one of policy_json or managed_policy_arns must be provided."
    }
  }
}

# ── Inline policy (caller-supplied JSON) ─────────────────────────────────────

resource "aws_iam_role_policy" "this" {
  count = var.policy_json != null ? 1 : 0

  name   = "workload-policy"
  role   = aws_iam_role.this.name
  policy = var.policy_json
}

# ── Managed / customer-managed policy attachments ────────────────────────────

resource "aws_iam_role_policy_attachment" "this" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

# ── EKS Pod Identity association ─────────────────────────────────────────────

resource "aws_eks_pod_identity_association" "this" {
  count = var.identity_type == "pod_identity" ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account
  role_arn        = aws_iam_role.this.arn

  tags = var.tags
}
