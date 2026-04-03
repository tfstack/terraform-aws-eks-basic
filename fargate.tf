locals {
  fargate_create_execution_role = length(var.fargate_profiles) > 0 && var.create_fargate_pod_execution_role

  fargate_pod_execution_role_arn_effective = length(var.fargate_profiles) == 0 ? null : (
    var.create_fargate_pod_execution_role ? aws_iam_role.eks_fargate[0].arn : var.fargate_pod_execution_role_arn
  )

  fargate_access_entry_count = (
    length(var.fargate_profiles) > 0
    && var.create_fargate_access_entry
    && var.cluster_authentication_mode != "CONFIG_MAP"
  ) ? 1 : 0
}

################################################################################
# Fargate Pod Execution IAM Role
################################################################################

data "aws_iam_policy_document" "eks_fargate_assume_role" {
  count = local.fargate_create_execution_role ? 1 : 0

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
  count = local.fargate_create_execution_role ? 1 : 0

  name                 = coalesce(var.fargate_pod_execution_role_name, "${var.name}-fargate-pod-execution")
  path                 = var.fargate_pod_execution_role_path
  assume_role_policy   = data.aws_iam_policy_document.eks_fargate_assume_role[0].json
  permissions_boundary = var.fargate_pod_execution_role_permissions_boundary
  tags                 = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_fargate" {
  count = local.fargate_create_execution_role ? 1 : 0

  role       = aws_iam_role.eks_fargate[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

################################################################################
# Fargate Profiles
################################################################################

resource "aws_eks_fargate_profile" "this" {
  for_each = var.fargate_profiles

  region = var.region

  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = each.key
  pod_execution_role_arn = local.fargate_pod_execution_role_arn_effective
  subnet_ids             = each.value.subnet_ids != null ? each.value.subnet_ids : var.subnet_ids

  dynamic "selector" {
    for_each = each.value.selectors
    content {
      namespace = selector.value.namespace
      labels    = try(selector.value.labels, null)
    }
  }

  tags = merge(var.tags, each.value.tags)

  depends_on = [aws_eks_cluster.this]
}

################################################################################
# Fargate access entry (API / API_AND_CONFIG_MAP only)
################################################################################

resource "aws_eks_access_entry" "fargate" {
  count = local.fargate_access_entry_count

  region = var.region

  cluster_name  = aws_eks_cluster.this.id
  principal_arn = local.fargate_pod_execution_role_arn_effective
  type          = var.fargate_access_entry_type

  tags = var.tags

  depends_on = [
    aws_eks_cluster.this,
  ]
}
