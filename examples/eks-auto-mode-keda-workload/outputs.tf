output "aws_region" {
  description = "AWS region (for update-kubeconfig)"
  value       = var.aws_region
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "sqs_role_arns" {
  description = "Map of IAM role ARNs for SQS access, keyed by namespace/service_account"
  value       = module.eks.sqs_role_arns
}

output "cluster_pod_identity_associations" {
  description = "Map of EKS Pod Identity associations created by the module"
  value       = module.eks.cluster_pod_identity_associations
}

