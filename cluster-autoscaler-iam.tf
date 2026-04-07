
################################################################################
# Cluster Autoscaler IAM (IRSA or EKS Pod Identity)
# For EC2 managed node groups only — not compatible with enable_automode or
# Fargate-only clusters. Requires eks-pod-identity-agent addon when using pod_identity.
################################################################################

# IAM assume role policy document for Cluster Autoscaler (IRSA)
data "aws_iam_policy_document" "cluster_autoscaler_assume_role_irsa" {
  count = var.enable_cluster_autoscaler_iam ? 1 : 0

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
      values   = ["system:serviceaccount:${var.cluster_autoscaler_namespace}:${var.cluster_autoscaler_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM assume role policy document for Cluster Autoscaler (EKS Pod Identity)
data "aws_iam_policy_document" "cluster_autoscaler_assume_role_pod_identity" {
  count = var.enable_cluster_autoscaler_iam ? 1 : 0

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

resource "aws_iam_role" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler_iam ? 1 : 0

  name               = "${var.name}-cluster-autoscaler-role"
  assume_role_policy = var.cluster_autoscaler_identity_type == "pod_identity" ? data.aws_iam_policy_document.cluster_autoscaler_assume_role_pod_identity[0].json : data.aws_iam_policy_document.cluster_autoscaler_assume_role_irsa[0].json

  tags = var.tags

  depends_on = [
    aws_iam_openid_connect_provider.oidc_provider
  ]

  lifecycle {
    precondition {
      condition     = !var.enable_cluster_autoscaler_iam || (!var.enable_automode && length(var.eks_managed_node_groups) > 0)
      error_message = "enable_cluster_autoscaler_iam requires at least one eks_managed_node_groups entry and is not supported when enable_automode is true."
    }
  }
}

# Permissions per kubernetes/autoscaler AWS provider README (autodiscovery + launch templates).
# Mutating autoscaling calls are restricted to ASGs tagged with eks:cluster-name matching this cluster.
data "aws_iam_policy_document" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler_iam ? 1 : 0

  statement {
    sid    = "AutoscalingEc2EksDescribe"
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AutoscalingMutateClusterScoped"
    effect = "Allow"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/eks:cluster-name"
      values   = [aws_eks_cluster.this.name]
    }
  }
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler_iam ? 1 : 0

  name   = "${var.name}-cluster-autoscaler"
  role   = aws_iam_role.cluster_autoscaler[0].id
  policy = data.aws_iam_policy_document.cluster_autoscaler[0].json
}

resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler_iam && var.cluster_autoscaler_identity_type == "pod_identity" ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  namespace       = var.cluster_autoscaler_namespace
  service_account = var.cluster_autoscaler_service_account
  role_arn        = aws_iam_role.cluster_autoscaler[0].arn
}
