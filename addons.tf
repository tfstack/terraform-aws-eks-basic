# =============================================================================
# EBS CSI Driver IAM (IRSA setup)
# =============================================================================

data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  name               = "${var.cluster_name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role[0].json
  tags               = var.tags

  # Explicit dependency to ensure OIDC provider exists before creating IRSA role
  depends_on = [
    aws_iam_openid_connect_provider.eks
  ]
}

resource "aws_iam_role_policy" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  name = "${var.cluster_name}-ebs-csi-driver-policy"
  role = aws_iam_role.ebs_csi_driver[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EBSCSIVolumeManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = data.aws_region.current.id
          }
        }
      },
      {
        Sid    = "EBSCSISnapshotManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = data.aws_region.current.id
          }
        }
      },
      {
        Sid    = "EBSCSIDescribeOperations"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeVolumes",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      },
      {
        Sid    = "EBSCSITaggingOperations"
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DescribeTags"
        ]
        Resource = [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*"
        ]
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = [
              "CreateVolume",
              "CreateSnapshot"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_eks_addon" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.ebs_csi_driver_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.ebs_csi_driver[0].arn

  depends_on = [
    aws_iam_role_policy.ebs_csi_driver[0]
  ]

  tags = var.tags
}

resource "kubernetes_storage_class" "ebs_csi_default" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }

  depends_on = [
    aws_eks_addon.ebs_csi_driver[0]
  ]
}

# =============================================================================
# EKS Pod Identity Agent
# =============================================================================

resource "aws_eks_addon" "pod_identity_agent" {
  count = var.enable_pod_identity_agent ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = var.pod_identity_agent_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
}

# =============================================================================
# AWS Load Balancer Controller IAM (IRSA setup)
# =============================================================================

data "aws_iam_policy_document" "aws_lb_controller_assume_role" {
  count = var.enable_aws_lb_controller ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "aws_lb_controller" {
  count = var.enable_aws_lb_controller ? 1 : 0

  name               = "${var.cluster_name}-aws-lb-controller"
  assume_role_policy = data.aws_iam_policy_document.aws_lb_controller_assume_role[0].json
  tags               = var.tags

  # Explicit dependency to ensure OIDC provider exists before creating IRSA role
  depends_on = [
    aws_iam_openid_connect_provider.eks
  ]
}

resource "aws_iam_role_policy_attachment" "aws_lb_controller" {
  count = var.enable_aws_lb_controller ? 1 : 0

  role       = aws_iam_role.aws_lb_controller[0].name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

resource "aws_iam_role_policy_attachment" "aws_lb_controller_ec2" {
  count = var.enable_aws_lb_controller ? 1 : 0

  role       = aws_iam_role.aws_lb_controller[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy" "aws_lb_controller_waf" {
  count = var.enable_aws_lb_controller ? 1 : 0

  name = "${var.cluster_name}-aws-lb-controller-waf"
  role = aws_iam_role.aws_lb_controller[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WAFv2Permissions"
        Effect = "Allow"
        Action = [
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "wafv2:ListWebACLs"
        ]
        Resource = "*"
      },
      {
        Sid    = "WAFRegionalPermissions"
        Effect = "Allow"
        Action = [
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "waf-regional:ListWebACLs"
        ]
        Resource = "*"
      },
      {
        Sid    = "ShieldPermissions"
        Effect = "Allow"
        Action = [
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "kubernetes_service_account" "aws_lb_controller" {
  count = var.enable_aws_lb_controller ? 1 : 0

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_lb_controller[0].arn
    }
    labels = {
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/component"  = "controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_role_policy_attachment.aws_lb_controller[0],
    aws_iam_role_policy_attachment.aws_lb_controller_ec2[0],
    aws_iam_role_policy.aws_lb_controller_waf[0]
  ]
}

resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_aws_lb_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.aws_lb_controller_helm_version

  set {
    name  = "clusterName"
    value = aws_eks_cluster.this.name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "region"
    value = data.aws_region.current.id
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  dynamic "set" {
    for_each = var.aws_lb_controller_helm_values
    content {
      name  = set.key
      value = set.value
    }
  }

  depends_on = [
    kubernetes_service_account.aws_lb_controller[0]
  ]
}
