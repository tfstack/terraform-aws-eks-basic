################################################################################
# EKS Capabilities
# Managed ACK, KRO, and ArgoCD capabilities running in AWS-managed infrastructure
################################################################################
# EKS checks the IAM role trust policy very early; wait for IAM to propagate before creating the capability.
resource "time_sleep" "capability" {
  for_each = var.capabilities

  create_duration = "20s"

  triggers = {
    iam_role_arn = try(each.value.role_arn, null) != null ? each.value.role_arn : aws_iam_role.capability[each.key].arn
  }
}

resource "aws_eks_capability" "this" {
  for_each = var.capabilities

  cluster_name    = aws_eks_cluster.this.name
  capability_name = upper(each.key)
  type            = local.capability_types[each.key]

  role_arn = time_sleep.capability[each.key].triggers["iam_role_arn"]

  # Set delete_propagation_policy from config (default: "RETAIN"). AWS currently only supports RETAIN.
  delete_propagation_policy = try(each.value.delete_propagation_policy, "RETAIN")

  tags = var.tags

  # Argo CD configuration (Identity Center, RBAC, namespace, network access)
  dynamic "configuration" {
    for_each = local.capability_types[each.key] == "ARGOCD" && try(each.value.configuration.argo_cd, null) != null ? [each.value.configuration] : []
    content {
      dynamic "argo_cd" {
        for_each = [configuration.value.argo_cd]
        content {
          namespace = try(argo_cd.value.namespace, null)
          dynamic "aws_idc" {
            for_each = try(argo_cd.value.aws_idc, null) != null ? [argo_cd.value.aws_idc] : []
            content {
              idc_instance_arn = aws_idc.value.idc_instance_arn
              idc_region       = try(aws_idc.value.idc_region, null)
            }
          }
          dynamic "rbac_role_mapping" {
            for_each = coalesce(try(argo_cd.value.rbac_role_mapping, []), [])
            content {
              role = rbac_role_mapping.value.role
              dynamic "identity" {
                for_each = rbac_role_mapping.value.identity
                content {
                  type = identity.value.type
                  id   = identity.value.id
                }
              }
            }
          }
          dynamic "network_access" {
            for_each = try(argo_cd.value.network_access, null) != null ? [argo_cd.value.network_access] : []
            content {
              vpce_ids = try(network_access.value.vpce_ids, null)
            }
          }
        }
      }
    }
  }

  depends_on = [
    aws_eks_cluster.this,
    time_sleep.capability
  ]
}
