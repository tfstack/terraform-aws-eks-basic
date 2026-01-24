# =============================================================================
# Fargate Profile IAM Role
# =============================================================================

data "aws_iam_policy_document" "eks_fargate_assume_role" {
  count = contains(var.compute_mode, "fargate") ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_fargate" {
  count = contains(var.compute_mode, "fargate") ? 1 : 0

  name               = "${var.cluster_name}-eks-fargate-role"
  assume_role_policy = data.aws_iam_policy_document.eks_fargate_assume_role[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_fargate_pod_execution_role" {
  count = contains(var.compute_mode, "fargate") ? 1 : 0

  role       = aws_iam_role.eks_fargate[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

# =============================================================================
# Fargate Profiles
# =============================================================================

resource "aws_eks_fargate_profile" "default" {
  for_each = contains(var.compute_mode, "fargate") ? var.fargate_profiles : {}

  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = each.key
  pod_execution_role_arn = aws_iam_role.eks_fargate[0].arn
  subnet_ids             = each.value.subnet_ids != null ? each.value.subnet_ids : var.subnet_ids

  dynamic "selector" {
    for_each = each.value.selectors != null ? each.value.selectors : []
    content {
      namespace = selector.value.namespace
      labels    = selector.value.labels
    }
  }

  tags = merge(var.tags, each.value.tags != null ? each.value.tags : {})

  depends_on = [
    aws_iam_role_policy_attachment.eks_fargate_pod_execution_role[0],
  ]
}
