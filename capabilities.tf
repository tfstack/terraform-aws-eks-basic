# =============================================================================
# EKS Capabilities
# Managed ACK, KRO, and ArgoCD capabilities running in AWS-managed infrastructure
# =============================================================================

resource "aws_eks_capability" "ack" {
  count = var.enable_ack_capability ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  capability_name = "ACK"
  type            = "ACK"

  # ACK requires a role ARN for creating AWS resources
  # Use provided role ARN or create one automatically
  role_arn = var.ack_capability_role_arn != null ? var.ack_capability_role_arn : aws_iam_role.ack_capability[0].arn

  delete_propagation_policy = "RETAIN"

  depends_on = [
    aws_eks_cluster.this
  ]

  tags = var.tags
}

resource "aws_eks_capability" "kro" {
  count = var.enable_kro_capability ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  capability_name = "KRO"
  type            = "KRO"

  # KRO requires a role ARN
  # Use provided role ARN or create one automatically
  role_arn = var.kro_capability_role_arn != null ? var.kro_capability_role_arn : aws_iam_role.kro_capability[0].arn

  delete_propagation_policy = "RETAIN"

  depends_on = [
    aws_eks_cluster.this
  ]

  tags = var.tags
}

# =============================================================================
# ArgoCD Capability (SCAFFOLDED - NOT SUPPORTED YET)
# =============================================================================
# ArgoCD capability requires AWS Identity Center configuration
# This is scaffolded for future implementation but not currently supported
# Uncomment and configure Identity Center before enabling
# =============================================================================

# resource "aws_eks_capability" "argocd" {
#   count = var.enable_argocd_capability ? 1 : 0
#
#   cluster_name    = aws_eks_cluster.this.name
#   capability_name = "ARGOCD"
#   type            = "ARGOCD"
#
#   # ArgoCD requires a role ARN
#   # Use provided role ARN or create one automatically
#   role_arn = var.argocd_capability_role_arn != null ? var.argocd_capability_role_arn : aws_iam_role.argocd_capability[0].arn
#
#   # ArgoCD requires configuration parameter with Identity Center details
#   configuration = var.argocd_capability_configuration != null ? var.argocd_capability_configuration : jsonencode({})
#
#   delete_propagation_policy = "RETAIN"
#
#   depends_on = [
#     aws_eks_cluster.this
#   ]
#
#   tags = var.tags
# }
