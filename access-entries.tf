# =============================================================================
# User Access Entries
# Grant cluster admin access to specified IAM users/roles
# =============================================================================

locals {
  # Determine if user access entries should be created
  # Only create when:
  # 1. cluster_admin_arns is not empty, AND
  # 2. Either capabilities are enabled OR authentication mode is not CONFIG_MAP
  create_user_access_entries = length(var.cluster_admin_arns) > 0 && (
    var.enable_ack_capability ||
    var.enable_kro_capability ||
    var.enable_argocd_capability ||
    var.cluster_authentication_mode != "CONFIG_MAP"
  )
}

resource "aws_eks_access_entry" "cluster_admins" {
  for_each = local.create_user_access_entries ? toset(var.cluster_admin_arns) : []

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"

  depends_on = [
    aws_eks_cluster.this
  ]
}

resource "aws_eks_access_policy_association" "cluster_admin_policy" {
  for_each = local.create_user_access_entries ? toset(var.cluster_admin_arns) : []

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [
    aws_eks_access_entry.cluster_admins
  ]
}

# =============================================================================
# EC2 Node Access Entry
# Required when using API or API_AND_CONFIG_MAP authentication mode
# =============================================================================

locals {
  # Determine if access entries are needed for EC2 nodes
  ec2_needs_access_entry = contains(var.compute_mode, "ec2") && (
    var.enable_ack_capability ||
    var.enable_kro_capability ||
    var.enable_argocd_capability ||
    var.cluster_authentication_mode != "CONFIG_MAP"
  )
}

resource "aws_eks_access_entry" "ec2_nodes" {
  count = local.ec2_needs_access_entry ? 1 : 0

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.eks_nodes[0].arn
  type          = "EC2_LINUX"

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_role.eks_nodes[0]
  ]
}

# =============================================================================
# Fargate Pod Access Entry
# Required when using API or API_AND_CONFIG_MAP authentication mode
# =============================================================================

locals {
  # Determine if access entries are needed for Fargate pods
  fargate_needs_access_entry = contains(var.compute_mode, "fargate") && (
    var.enable_ack_capability ||
    var.enable_kro_capability ||
    var.enable_argocd_capability ||
    var.cluster_authentication_mode != "CONFIG_MAP"
  )
}

resource "aws_eks_access_entry" "fargate_pods" {
  count = local.fargate_needs_access_entry ? 1 : 0

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.eks_fargate[0].arn
  type          = "FARGATE_LINUX"

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_role.eks_fargate[0]
  ]
}
