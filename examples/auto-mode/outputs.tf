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

# ── Headlamp Cognito ──────────────────────────────────────────────────────────

output "headlamp_cognito_user_pool_id" {
  description = "Cognito User Pool ID for headlamp OIDC."
  value       = aws_cognito_user_pool.headlamp.id
}

output "headlamp_cognito_client_id" {
  description = "Cognito App Client ID for headlamp (= OIDC_CLIENT_ID in the Secrets Manager secret)."
  value       = aws_cognito_user_pool_client.headlamp.id
}

output "headlamp_cognito_issuer_url" {
  description = "Cognito OIDC issuer URL (= OIDC_ISSUER_URL). Also used in aws_eks_identity_provider_config."
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.headlamp.id}"
}

output "headlamp_cognito_saml_acs_url" {
  description = "Cognito SAML ACS URL — paste into Identity Center custom SAML app as the ACS URL / reply URL (phase 2 setup)."
  value       = "https://${aws_cognito_user_pool_domain.headlamp.domain}.auth.${var.aws_region}.amazoncognito.com/saml2/idpresponse"
}

output "headlamp_cognito_saml_entity_id" {
  description = "Cognito SAML Entity ID / Audience — paste into Identity Center custom SAML app (phase 2 setup)."
  value       = "urn:amazon:cognito:sp:${aws_cognito_user_pool.headlamp.id}"
}

output "headlamp_secrets_manager_secret_arn" {
  description = "ARN of the headlamp/oidc Secrets Manager secret consumed by Secrets Store CSI."
  value       = aws_secretsmanager_secret.headlamp_oidc.arn
}

