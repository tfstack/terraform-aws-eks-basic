# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

# EKS Cluster Outputs
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

output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller (Pod Identity)"
  value       = module.eks.aws_load_balancer_controller_role_arn
}

output "external_dns_role_arn" {
  description = "IAM role ARN for External DNS (Pod Identity)"
  value       = module.eks.external_dns_role_arn
}

output "cluster_pod_identity_associations" {
  description = "Pod Identity associations created for the cluster"
  value       = module.eks.cluster_pod_identity_associations
}
