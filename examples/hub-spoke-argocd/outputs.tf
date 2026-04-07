output "aws_region" {
  description = "AWS region (for aws eks update-kubeconfig)"
  value       = var.aws_region
}

output "vpc_id" {
  description = "Shared VPC ID for hub and spokes; set aws-load-balancer-controller Helm vpcId in kube-infra overlays for eks-11/eks-12"
  value       = module.vpc.vpc_id
}

# ── Hub ───────────────────────────────────────────────────────────────────────

output "hub_cluster_name" {
  description = "Name of the hub EKS cluster"
  value       = module.eks_hub.cluster_name
}

output "hub_cluster_endpoint" {
  description = "Endpoint for the hub EKS control plane"
  value       = module.eks_hub.cluster_endpoint
}

output "hub_cluster_arn" {
  description = "EKS cluster ARN for eks-10 (use as server in Argo CD in-cluster Secret; same pattern as root-eks-10.yaml)"
  value       = module.eks_hub.cluster_arn
}

output "hub_oidc_provider_arn" {
  description = "OIDC provider ARN for the hub cluster"
  value       = module.eks_hub.oidc_provider_arn
}

# Used by spoke clusters to grant Argo CD deploy access.
output "hub_argocd_capability_role_arn" {
  description = "ARN of the hub Argo CD capability IAM role. This is automatically granted cluster-admin on spoke clusters via access_entries."
  value       = module.eks_hub.cluster_capability_role_arns["argocd"]
}

# ── Spokes ────────────────────────────────────────────────────────────────────

output "spoke_1_cluster_name" {
  description = "Name of the first spoke EKS cluster (module eks_spoke_1)"
  value       = module.eks_spoke_1.cluster_name
}

output "spoke_1_cluster_endpoint" {
  description = "Endpoint for the first spoke EKS control plane"
  value       = module.eks_spoke_1.cluster_endpoint
}

output "spoke_1_cluster_arn" {
  description = "EKS cluster ARN for eks-11 — required value for Argo CD remote cluster Secret server (with awsAuthConfig); do not use spoke_1_cluster_endpoint there"
  value       = module.eks_spoke_1.cluster_arn
}

output "spoke_1_oidc_provider_arn" {
  description = "OIDC provider ARN for the first spoke cluster"
  value       = module.eks_spoke_1.oidc_provider_arn
}

output "spoke_2_cluster_name" {
  description = "Name of the second spoke EKS cluster (module eks_spoke_2)"
  value       = module.eks_spoke_2.cluster_name
}

output "spoke_2_cluster_endpoint" {
  description = "Endpoint for the second spoke EKS control plane"
  value       = module.eks_spoke_2.cluster_endpoint
}

output "spoke_2_cluster_arn" {
  description = "EKS cluster ARN for eks-12 — required value for Argo CD remote cluster Secret server (with awsAuthConfig); do not use spoke_2_cluster_endpoint there"
  value       = module.eks_spoke_2.cluster_arn
}

output "spoke_2_oidc_provider_arn" {
  description = "OIDC provider ARN for the second spoke cluster"
  value       = module.eks_spoke_2.oidc_provider_arn
}

# ── Argo CD CodeConnections ───────────────────────────────────────────────────

output "argocd_connection_ids" {
  description = "Map of CodeConnections UUIDs keyed by connection name. Use these UUIDs in Argo CD Application repoURLs."
  value       = module.argocd_connections.connection_ids
}

output "argocd_codeconnections_iam_role_name" {
  description = "IAM role name that has CodeConnections UseConnection/GetConnection attached (hub Argo CD capability role)."
  value       = module.argocd_connections.codeconnections_iam_role_name
}

output "argocd_codeconnections_iam_policy_name" {
  description = "Inline policy name on the hub Argo CD role for CodeConnections."
  value       = module.argocd_connections.codeconnections_iam_policy_name
}
