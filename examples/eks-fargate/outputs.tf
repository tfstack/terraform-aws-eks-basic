output "aws_region" {
  description = "AWS region (for update-kubeconfig)"
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

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  value       = module.eks.oidc_provider_arn
}

output "fargate_role_arn" {
  description = "ARN of the Fargate pod execution IAM role"
  value       = module.eks.fargate_role_arn
}

output "fargate_profiles" {
  description = "Map of EKS Fargate profiles created"
  value       = module.eks.fargate_profiles
}

output "fargate_access_entry_arn" {
  description = "ARN of the module-managed Fargate access entry (when created)"
  value       = module.eks.fargate_access_entry_arn
}
