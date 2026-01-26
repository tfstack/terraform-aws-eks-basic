# =============================================================================
# EC2 Node IAM Role
# =============================================================================

data "aws_iam_policy_document" "eks_nodes_assume_role" {
  count = contains(var.compute_mode, "ec2") ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_nodes" {
  count = contains(var.compute_mode, "ec2") ? 1 : 0

  name               = "${var.cluster_name}-eks-nodes-role"
  assume_role_policy = data.aws_iam_policy_document.eks_nodes_assume_role[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_nodes_worker" {
  count = contains(var.compute_mode, "ec2") ? 1 : 0

  role       = aws_iam_role.eks_nodes[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_nodes_cni" {
  count = contains(var.compute_mode, "ec2") ? 1 : 0

  role       = aws_iam_role.eks_nodes[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_nodes_ecr" {
  count = contains(var.compute_mode, "ec2") ? 1 : 0

  role       = aws_iam_role.eks_nodes[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# =============================================================================
# EC2 Managed Node Group
# =============================================================================

resource "aws_eks_node_group" "default" {
  count = contains(var.compute_mode, "ec2") ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-default"
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids      = var.node_subnet_ids != null ? var.node_subnet_ids : var.subnet_ids

  instance_types = var.node_instance_types

  disk_size = var.node_disk_size

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = var.node_update_max_unavailable
  }

  dynamic "remote_access" {
    for_each = var.node_remote_access_enabled ? [1] : []
    content {
      ec2_ssh_key               = var.node_remote_access_ssh_key
      source_security_group_ids = var.node_remote_access_security_groups
    }
  }

  labels = var.node_labels

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_nodes_worker[0],
    aws_iam_role_policy_attachment.eks_nodes_cni[0],
    aws_iam_role_policy_attachment.eks_nodes_ecr[0]
  ]
}
