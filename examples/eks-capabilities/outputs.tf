output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_capabilities" {
  description = "EKS capability resources (ACK, KRO, Argo CD)"
  value       = module.eks.cluster_capabilities
}

output "cluster_capability_role_arns" {
  description = "IAM role ARNs for capabilities created by the module"
  value       = module.eks.cluster_capability_role_arns
}
