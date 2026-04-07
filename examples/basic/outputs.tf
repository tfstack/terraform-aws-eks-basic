output "aws_region" {
  description = "AWS region (for aws eks update-kubeconfig)"
  value       = var.aws_region
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = module.eks.cluster_version
}

output "karpenter_node_role_name" {
  description = "IAM role name for Karpenter-provisioned nodes (must match EC2NodeClass spec.role in kube-infra)"
  value       = module.eks.karpenter_node_role_name
}

output "karpenter_interruption_queue_name" {
  description = "SQS queue name for Karpenter settings.interruptionQueue"
  value       = module.eks.karpenter_interruption_queue_name
}

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  value       = module.eks.oidc_provider_arn
}

output "argocd_connection_ids" {
  description = "Map of CodeConnection UUIDs keyed by connection name. Use these UUIDs in Argo CD Application repoURLs."
  value       = var.argocd_idc_instance_arn != null ? module.argocd_connections[0].connection_ids : null
}

output "argocd_codeconnections_iam_role_name" {
  description = "IAM role name that has CodeConnections UseConnection/GetConnection attached (Argo CD capability role)."
  value       = var.argocd_idc_instance_arn != null ? module.argocd_connections[0].codeconnections_iam_role_name : null
}

output "argocd_codeconnections_iam_policy_name" {
  description = "Inline policy name on the Argo CD role for CodeConnections."
  value       = var.argocd_idc_instance_arn != null ? module.argocd_connections[0].codeconnections_iam_policy_name : null
}
