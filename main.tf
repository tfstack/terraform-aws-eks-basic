# Get current AWS region
data "aws_region" "current" {}

# =============================================================================
# EKS Cluster IAM Role
# =============================================================================

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.cluster_name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# =============================================================================
# OIDC Provider for IRSA
# =============================================================================

data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = var.tags

  # Explicit dependencies to ensure proper creation order
  depends_on = [
    aws_eks_cluster.this,
    data.tls_certificate.eks
  ]
}

# =============================================================================
# EKS Cluster
# =============================================================================

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = var.endpoint_public_access
    endpoint_private_access = true
    public_access_cidrs     = var.public_access_cidrs
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  # Access configuration - required for EKS Capabilities
  # Capabilities require API or API_AND_CONFIG_MAP authentication mode
  # Use dynamic block to only set when capabilities are enabled
  dynamic "access_config" {
    for_each = (var.enable_ack_capability || var.enable_kro_capability || var.enable_argocd_capability) || var.cluster_authentication_mode != "CONFIG_MAP" ? [1] : []
    content {
      authentication_mode = var.cluster_authentication_mode != "CONFIG_MAP" ? var.cluster_authentication_mode : "API_AND_CONFIG_MAP"
    }
  }

  # AutoMode configuration is handled via the compute block
  # Note: AutoMode support may require specific AWS provider versions
  # This structure is ready for future AutoMode expansion

  tags = var.tags

  lifecycle {
    # Ignore changes to access_config if it was manually set or already exists
    # This prevents replacement when capabilities are enabled on existing clusters
    ignore_changes = [access_config]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
}
