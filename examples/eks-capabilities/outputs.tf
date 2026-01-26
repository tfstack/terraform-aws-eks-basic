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

output "cluster_ca_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_ca_data
  sensitive   = true
}

# EKS Capabilities Outputs
output "ack_capability_arn" {
  description = "ARN of the ACK capability"
  value       = module.eks.ack_capability_arn
}

output "kro_capability_arn" {
  description = "ARN of the KRO capability"
  value       = module.eks.kro_capability_arn
}

output "argocd_capability_arn" {
  description = "ARN of the ArgoCD capability"
  value       = module.eks.argocd_capability_arn
}

# Additional Outputs for Kubernetes Resources
output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "oidc_provider_url" {
  description = "OIDC Provider URL (without https://)"
  value       = replace(module.eks.oidc_provider_url, "https://", "")
}

# Instructions
output "next_steps" {
  description = "Next steps to use the capabilities"
  value       = <<-EOT
    Capabilities are now enabled! Kubernetes resources have been automatically deployed.

    1. Configure kubectl:
       aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}

    2. Verify RBAC for KRO (automatically deployed):
       kubectl get clusterrolebinding eks-capabilities-kro-cluster-admin

    3. Verify Resource Graph Definition (automatically deployed):
       kubectl get resourcegraphdefinition eks-capabilities-appstack.kro.run

    4. Verify ACK resources (automatically deployed):
       kubectl get table,bucket,role

    6. Verify capabilities:
       kubectl api-resources | grep -E "(resourcegraphdefinition|table|bucket|role)"
  EOT
}
