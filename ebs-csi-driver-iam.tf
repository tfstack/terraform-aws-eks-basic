
################################################################################
# EBS CSI Driver IAM Role (EKS Pod Identity)
# IAM role required to manage EBS CSI driver
################################################################################

# IAM assume role policy document for EBS CSI driver (EKS Pod Identity)
data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
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

# IAM role for EBS CSI driver
resource "aws_iam_role" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  name               = "${var.name}-ebs-csi-driver-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role[0].json

  tags = var.tags
}

# Attach AWS managed policy for EBS CSI driver
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  role       = aws_iam_role.ebs_csi_driver[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# EKS Pod Identity association for EBS CSI driver
resource "aws_eks_pod_identity_association" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  namespace       = var.ebs_csi_driver_namespace
  service_account = var.ebs_csi_driver_service_account
  role_arn        = aws_iam_role.ebs_csi_driver[0].arn
}
