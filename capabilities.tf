################################################################################
# EKS Capabilities
# Managed ACK, KRO, and ArgoCD capabilities running in AWS-managed infrastructure
################################################################################

resource "aws_eks_capability" "this" {
  for_each = var.capabilities

  cluster_name    = aws_eks_cluster.this.name
  capability_name = upper(each.key)
  type            = local.capability_types[each.key]

  # Use provided role_arn if specified, otherwise use created role
  role_arn = try(each.value.role_arn, null) != null ? each.value.role_arn : aws_iam_role.capability[each.key].arn

  # Set delete_propagation_policy from config (default: "RETAIN")
  delete_propagation_policy = try(each.value.delete_propagation_policy, "RETAIN")

  tags = var.tags

  depends_on = [
    aws_eks_cluster.this
  ]

  # IAM role dependency is handled conditionally - only when role_arn is not provided
  # The role_arn reference will create an implicit dependency

  # Note: Configuration parameter for ArgoCD is not directly supported in the resource
  # ArgoCD capability configuration must be handled via AWS Identity Center setup
  # before enabling the capability
}
