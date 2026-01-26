output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_ca_certificate" {
  description = "Decoded certificate data required to communicate with the cluster"
  value       = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
}

output "cluster_auth_token" {
  description = "Token to authenticate with the EKS cluster"
  value       = data.aws_eks_cluster_auth.this.token
  sensitive   = true
}

output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "URL of the EKS OIDC provider"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# =============================================================================
# EC2 Outputs
# =============================================================================

output "node_group_id" {
  description = "ID of the EKS node group (when EC2 mode is enabled)"
  value       = contains(var.compute_mode, "ec2") ? aws_eks_node_group.default[0].id : null
}

output "node_group_arn" {
  description = "ARN of the EKS node group (when EC2 mode is enabled)"
  value       = contains(var.compute_mode, "ec2") ? aws_eks_node_group.default[0].arn : null
}

output "node_group_status" {
  description = "Status of the EKS node group (when EC2 mode is enabled)"
  value       = contains(var.compute_mode, "ec2") ? aws_eks_node_group.default[0].status : null
}

output "node_role_arn" {
  description = "IAM role ARN for EC2 nodes (when EC2 mode is enabled)"
  value       = contains(var.compute_mode, "ec2") ? aws_iam_role.eks_nodes[0].arn : null
}

# =============================================================================
# Fargate Outputs
# =============================================================================

output "fargate_profile_arns" {
  description = "Map of Fargate profile ARNs (when Fargate mode is enabled)"
  value = contains(var.compute_mode, "fargate") ? {
    for k, v in aws_eks_fargate_profile.default : k => v.arn
  } : {}
}

output "fargate_role_arn" {
  description = "IAM role ARN for Fargate pods (when Fargate mode is enabled)"
  value       = contains(var.compute_mode, "fargate") ? aws_iam_role.eks_fargate[0].arn : null
}

# =============================================================================
# Addon Outputs
# =============================================================================

output "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI Driver (when enabled)"
  value       = var.enable_ebs_csi_driver ? aws_iam_role.ebs_csi_driver[0].arn : null
}

output "aws_lb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller (when enabled)"
  value       = var.enable_aws_lb_controller ? aws_iam_role.aws_lb_controller[0].arn : null
}

# =============================================================================
# EKS Capabilities Outputs
# =============================================================================

output "ack_capability_arn" {
  description = "ARN of the ACK capability (when enabled)"
  value       = var.enable_ack_capability ? aws_eks_capability.ack[0].arn : null
}

output "kro_capability_arn" {
  description = "ARN of the KRO capability (when enabled)"
  value       = var.enable_kro_capability ? aws_eks_capability.kro[0].arn : null
}

output "argocd_capability_arn" {
  description = "ARN of the ArgoCD capability (when enabled). NOTE: ArgoCD not currently supported - scaffolded for future use."
  value       = null # ArgoCD capability is commented out (scaffolded)
}

# =============================================================================
# Access Entry Outputs
# =============================================================================

output "ec2_access_entry_created" {
  description = "Whether an access entry was created for EC2 nodes"
  value       = local.ec2_needs_access_entry
}

output "fargate_access_entry_created" {
  description = "Whether an access entry was created for Fargate pods"
  value       = local.fargate_needs_access_entry
}
