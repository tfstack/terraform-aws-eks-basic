################################################################################
# EKS Capabilities – Additional Access Entry Policy Associations
# EKS auto-creates an access entry for each capability role; this associates
# extra policies (e.g. AmazonEKSSecretReaderPolicy for ACK) with that entry.
################################################################################

resource "aws_eks_access_policy_association" "capability" {
  for_each = local.flattened_capability_policy_associations

  region = var.region

  cluster_name  = aws_eks_cluster.this.id
  policy_arn    = each.value.policy_arn
  principal_arn = each.value.principal_arn

  access_scope {
    type       = each.value.scope_type
    namespaces = each.value.scope_namespaces
  }

  depends_on = [
    aws_eks_capability.this,
  ]
}
