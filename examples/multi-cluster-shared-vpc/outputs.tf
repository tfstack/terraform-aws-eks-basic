output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "Shared VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

# Classic
output "classic_cluster_name" {
  value = module.eks_classic.cluster_name
}

output "classic_cluster_endpoint" {
  value = module.eks_classic.cluster_endpoint
}

output "classic_oidc_provider_arn" {
  value = module.eks_classic.oidc_provider_arn
}

output "classic_argocd_connection_ids" {
  description = "CodeConnection UUIDs for the classic cluster Argo CD (repoURL must use these)"
  value       = var.argocd_idc_instance_arn != null ? module.argocd_connections_classic[0].connection_ids : null
}

# Fargate
output "fargate_cluster_name" {
  value = module.eks_fargate.cluster_name
}

output "fargate_cluster_endpoint" {
  value = module.eks_fargate.cluster_endpoint
}

output "fargate_oidc_provider_arn" {
  value = module.eks_fargate.oidc_provider_arn
}

output "fargate_argocd_connection_ids" {
  value = var.argocd_idc_instance_arn != null ? module.argocd_connections_fargate[0].connection_ids : null
}

output "fargate_aws_load_balancer_controller_role_arn" {
  description = "IRSA role for AWS Load Balancer Controller on the Fargate cluster (use in Helm serviceAccount.annotation)"
  value       = module.eks_fargate.aws_load_balancer_controller_role_arn
}

output "fargate_profiles" {
  value = module.eks_fargate.fargate_profiles
}

# Auto Mode
output "automode_cluster_name" {
  value = module.eks_automode.cluster_name
}

output "automode_cluster_endpoint" {
  value = module.eks_automode.cluster_endpoint
}

output "automode_oidc_provider_arn" {
  value = module.eks_automode.oidc_provider_arn
}

output "automode_argocd_connection_ids" {
  value = var.argocd_idc_instance_arn != null ? module.argocd_connections_automode[0].connection_ids : null
}
