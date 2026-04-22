
################################################################################
# EBS CSI Driver IAM Role (IRSA or EKS Pod Identity)
# IAM role required to manage EBS CSI driver
################################################################################

# IAM assume role policy document for EBS CSI driver (IRSA)
data "aws_iam_policy_document" "ebs_csi_driver_assume_role_irsa" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc_provider[0].arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.ebs_csi_driver_namespace}:${var.ebs_csi_driver_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM assume role policy document for EBS CSI driver (EKS Pod Identity)
data "aws_iam_policy_document" "ebs_csi_driver_assume_role_pod_identity" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

# IAM role for EBS CSI driver (IRSA or Pod Identity per ebs_csi_driver_identity_type)
resource "aws_iam_role" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  name               = "${var.name}-ebs-csi-driver-role"
  assume_role_policy = var.ebs_csi_driver_identity_type == "pod_identity" ? data.aws_iam_policy_document.ebs_csi_driver_assume_role_pod_identity[0].json : data.aws_iam_policy_document.ebs_csi_driver_assume_role_irsa[0].json

  # AmazonEBSCSIDriverEKSClusterScopedPolicy uses aws:PrincipalTag/eks-cluster-name on this role.
  tags = merge(var.tags, { "eks-cluster-name" = aws_eks_cluster.this.name })

  depends_on = [
    aws_iam_openid_connect_provider.oidc_provider
  ]
}

# Attach AWS managed policy for EBS CSI driver
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  role       = aws_iam_role.ebs_csi_driver[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEBSCSIDriverEKSClusterScopedPolicy"
}

# EKS Pod Identity association for EBS CSI driver (when using Pod Identity)
resource "aws_eks_pod_identity_association" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver && var.ebs_csi_driver_identity_type == "pod_identity" ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  namespace       = var.ebs_csi_driver_namespace
  service_account = var.ebs_csi_driver_service_account
  role_arn        = aws_iam_role.ebs_csi_driver[0].arn
}
