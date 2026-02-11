################################################################################
# Cluster
################################################################################

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "The Kubernetes version for the cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_platform_version" {
  description = "Platform version for the cluster"
  value       = aws_eks_cluster.this.platform_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = try(aws_eks_cluster.this.certificate_authority[0].data, null)
}

output "cluster_ca_certificate" {
  description = "Decoded certificate data required to communicate with the cluster"
  value       = try(base64decode(aws_eks_cluster.this.certificate_authority[0].data), null)
}

output "cluster_auth_token" {
  description = "Token to authenticate with the EKS cluster"
  value       = data.aws_eks_cluster_auth.this.token
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = try(aws_eks_cluster.this.identity[0].oidc[0].issuer, null)
}

output "cluster_ip_family" {
  description = "The IP family used by the cluster (e.g. ipv4 or ipv6)"
  value       = try(aws_eks_cluster.this.kubernetes_network_config[0].ip_family, null)
}

output "cluster_service_cidr" {
  description = "The IPv4 CIDR block where Kubernetes pod and service IP addresses are assigned from"
  value       = try(aws_eks_cluster.this.kubernetes_network_config[0].service_ipv4_cidr, null)
}

output "cluster_service_ipv6_cidr" {
  description = "The IPv6 CIDR block where Kubernetes pod and service IP addresses are assigned from (when ip_family is ipv6)"
  value       = try(aws_eks_cluster.this.kubernetes_network_config[0].service_ipv6_cidr, null)
}

output "cluster_primary_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster"
  value       = try(aws_eks_cluster.this.vpc_config[0].cluster_security_group_id, null)
}

################################################################################
# KMS Key
################################################################################

output "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of the key"
  value       = try(aws_kms_key.this[0].arn, null)
}

output "kms_key_id" {
  description = "The globally unique identifier for the key"
  value       = try(aws_kms_key.this[0].id, null)
}

################################################################################
# Security Groups
################################################################################

output "cluster_security_group_id" {
  description = "ID of the cluster security group"
  value       = try(aws_security_group.cluster[0].id, null)
}

output "node_security_group_id" {
  description = "ID of the node shared security group"
  value       = try(aws_security_group.node[0].id, null)
}

################################################################################
# IAM Roles
################################################################################

output "cluster_iam_role_arn" {
  description = "Cluster IAM role ARN"
  value       = try(aws_iam_role.this[0].arn, null)
}

output "cluster_iam_role_name" {
  description = "Cluster IAM role name"
  value       = try(aws_iam_role.this[0].name, null)
}

output "node_iam_role_arn" {
  description = "Node IAM role ARN"
  value       = try(aws_iam_role.eks_nodes[0].arn, null)
}

output "node_iam_role_name" {
  description = "Node IAM role name"
  value       = try(aws_iam_role.eks_nodes[0].name, null)
}

output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller (when enabled)"
  value       = try(aws_iam_role.aws_lb_controller[0].arn, null)
}

################################################################################
# OIDC Provider
################################################################################

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = try(aws_iam_openid_connect_provider.oidc_provider[0].arn, null)
}

output "oidc_provider" {
  description = "The OpenID Connect identity provider (issuer URL without leading `https://`)"
  value       = try(replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", ""), null)
}

################################################################################
# Access Entries
################################################################################

output "access_entries" {
  description = "Map of access entries created and their attributes"
  value       = aws_eks_access_entry.this
}

output "access_policy_associations" {
  description = "Map of eks cluster access policy associations created and their attributes"
  value       = aws_eks_access_policy_association.this
}

################################################################################
# CloudWatch Log Group
################################################################################

output "cloudwatch_log_group_name" {
  description = "Name of cloudwatch log group created"
  value       = coalesce(try(aws_cloudwatch_log_group.this_allow_destroy[0].name, null), try(aws_cloudwatch_log_group.this_prevent_destroy[0].name, null))
}

output "cloudwatch_log_group_arn" {
  description = "Arn of cloudwatch log group created"
  value       = coalesce(try(aws_cloudwatch_log_group.this_allow_destroy[0].arn, null), try(aws_cloudwatch_log_group.this_prevent_destroy[0].arn, null))
}

################################################################################
# EKS Addons
################################################################################

output "cluster_addons" {
  description = "Map of attribute maps for all EKS cluster addons enabled"
  value       = merge(aws_eks_addon.before_compute, aws_eks_addon.this)
}

################################################################################
# EKS Managed Node Groups
################################################################################

output "eks_managed_node_groups" {
  description = "Map of attribute maps for all EKS managed node groups created"
  value       = aws_eks_node_group.this
}

################################################################################
# Launch Templates
################################################################################

output "launch_templates" {
  description = "Map of launch templates created for node groups"
  value       = aws_launch_template.node_group
}
