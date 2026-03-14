output "aws_region" {
  description = "AWS region (for update-kubeconfig)"
  value       = var.aws_region
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

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  value       = module.eks.oidc_provider_arn
}

output "argocd_connection_ids" {
  description = "CodeConnections connection IDs (when Argo CD + submodule enabled). Use with argocd_repo_url_template to build source.repoURL."
  value       = var.argocd_idc_instance_arn != null ? module.argocd_connections[0].connection_ids : {}
}

output "argocd_repo_url_template" {
  description = "CodeConnections URL template for Applications (when Argo CD + submodule enabled). Replace OWNER/REPO with your repo (e.g. myorg/my-repo)."
  value       = var.argocd_idc_instance_arn != null ? module.argocd_connections[0].repository_url_templates["github"] : null
}
