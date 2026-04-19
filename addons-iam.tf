################################################################################
# Addon IAM Roles (IRSA or Pod Identity)
# IAM roles required for EKS addons that need service account permissions
################################################################################

# Service account names for addons that require IRSA (when addon_identity_type = "irsa")
locals {
  addon_service_accounts = {
    "aws-ebs-csi-driver" = {
      namespace = "kube-system"
      name      = "ebs-csi-controller-sa"
    }
    "aws-efs-csi-driver" = {
      namespace = "kube-system"
      name      = "efs-csi-controller-sa"
    }
    "aws-fsx-csi-driver" = {
      namespace = "kube-system"
      name      = "fsx-csi-controller-sa"
    }
    "aws-mountpoint-s3-csi-driver" = {
      namespace = "kube-system"
      name      = "s3-csi-driver-sa"
    }
    "external-dns" = {
      namespace = "external-dns"
      name      = "external-dns"
    }
  }

  # Addons that get a module-created role: from local.addon_service_accounts (IRSA) or var.addon_service_accounts (Pod Identity).
  # Exclude aws-ebs-csi-driver when enable_ebs_csi_driver is true (dedicated IAM in ebs-csi-driver-iam.tf).
  addon_role_config = var.addon_identity_type == "irsa" ? {
    for k, v in var.addons : k => local.addon_service_accounts[k]
    if contains(keys(local.addon_service_accounts), k) && try(v.service_account_role_arn, null) == null && !(k == "aws-ebs-csi-driver" && var.enable_ebs_csi_driver)
    } : {
    for k, v in var.addons : k => var.addon_service_accounts[k]
    if contains(keys(var.addon_service_accounts), k) && try(v.service_account_role_arn, null) == null && !(k == "aws-ebs-csi-driver" && var.enable_ebs_csi_driver)
  }
}

# IAM assume role policy documents for addons (IRSA)
data "aws_iam_policy_document" "addon_assume_role" {
  for_each = {
    for k, v in local.addon_role_config : k => v
    if var.addon_identity_type == "irsa"
  }

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
      values   = ["system:serviceaccount:${local.addon_role_config[each.key].namespace}:${local.addon_role_config[each.key].name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM assume role policy documents for addons (EKS Pod Identity)
data "aws_iam_policy_document" "addon_assume_role_pod_identity" {
  for_each = {
    for k, v in local.addon_role_config : k => v
    if var.addon_identity_type == "pod_identity"
  }

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

# IAM roles for addons (IRSA or Pod Identity per addon_identity_type)
resource "aws_iam_role" "addon" {
  for_each = local.addon_role_config

  name               = "${var.name}-${replace(each.key, "-", "_")}-addon-role"
  assume_role_policy = var.addon_identity_type == "pod_identity" ? data.aws_iam_policy_document.addon_assume_role_pod_identity[each.key].json : data.aws_iam_policy_document.addon_assume_role[each.key].json

  tags = var.tags

  depends_on = [
    aws_iam_openid_connect_provider.oidc_provider
  ]
}

# Pod Identity for var.addons is on aws_eks_addon.pod_identity_association (not aws_eks_pod_identity_association).

# Attach AWS managed policy for EBS CSI driver (addon path only; when enable_ebs_csi_driver is false)
resource "aws_iam_role_policy_attachment" "addon_ebs_csi_driver" {
  for_each = {
    for k, v in local.addon_role_config : k => v
    if k == "aws-ebs-csi-driver"
  }

  role       = aws_iam_role.addon[each.key].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "addon_efs_csi_driver" {
  for_each = {
    for k, v in local.addon_role_config : k => v
    if k == "aws-efs-csi-driver"
  }

  role       = aws_iam_role.addon[each.key].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

# FSx for Lustre CSI: narrower than AmazonFSxFullAccess — FSx API only, EC2/KMS needed by the driver, no CloudWatch/Firehose/DS extras from the managed policy.
data "aws_iam_policy_document" "addon_fsx_csi_driver" {
  statement {
    sid       = "FSxAPI"
    effect    = "Allow"
    actions   = ["fsx:*"]
    resources = ["*"]
  }

  statement {
    sid       = "CreateSLRForFSx"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["fsx.amazonaws.com"]
    }
  }

  statement {
    sid       = "CreateSLRForLustreS3Integration"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["s3.data-source.lustre.fsx.amazonaws.com"]
    }
  }

  statement {
    sid    = "DescribeEC2VpcResourcesViaFSx"
    effect = "Allow"
    actions = [
      "ec2:DescribeSecurityGroups",
      "ec2:GetSecurityGroupsForVpc",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeRouteTables",
    ]
    resources = ["*"]
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:CalledVia"
      values   = ["fsx.amazonaws.com"]
    }
  }

  statement {
    sid    = "EC2SecurityGroupsForCSI"
    effect = "Allow"
    actions = [
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeSecurityGroups",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateTags",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeAvailabilityZones",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EC2CreateTagsRouteTableForFsx"
    effect = "Allow"
    actions = [
      "ec2:CreateTags"
    ]
    resources = ["arn:${data.aws_partition.current.partition}:ec2:*:*:route-table/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/AmazonFSx"
      values   = ["ManagedByAmazonFSx"]
    }
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:CalledVia"
      values   = ["fsx.amazonaws.com"]
    }
  }

  statement {
    sid    = "KMSForEncryptedFileSystems"
    effect = "Allow"
    actions = [
      "kms:CreateGrant",
      "kms:DescribeKey",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "addon_fsx_csi_driver" {
  for_each = {
    for k, v in local.addon_role_config : k => v
    if k == "aws-fsx-csi-driver"
  }

  name   = "${var.name}-fsx-csi-addon-inline"
  role   = aws_iam_role.addon[each.key].id
  policy = data.aws_iam_policy_document.addon_fsx_csi_driver.json
}

# Mountpoint S3 CSI: object-level S3 access only (no bucket administration). Buckets are still wildcard — scope further with a dedicated role if needed.
data "aws_iam_policy_document" "addon_mountpoint_s3_csi_driver" {
  statement {
    sid    = "S3ObjectDataPlane"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectAttributes",
      "s3:GetObjectVersionAttributes",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
      "s3:ListBucketMultipartUploads",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:ListBucketVersions",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::*",
      "arn:${data.aws_partition.current.partition}:s3:::*/*",
    ]
  }

  statement {
    sid       = "STSForDirectoryBuckets"
    effect    = "Allow"
    actions   = ["sts:GetServiceBearerToken"]
    resources = ["*"]
  }

  statement {
    sid       = "S3ExpressDirectoryBuckets"
    effect    = "Allow"
    actions   = ["s3express:CreateSession"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "addon_mountpoint_s3_csi_driver" {
  for_each = {
    for k, v in local.addon_role_config : k => v
    if k == "aws-mountpoint-s3-csi-driver"
  }

  name   = "${var.name}-mountpoint-s3-addon-inline"
  role   = aws_iam_role.addon[each.key].id
  policy = data.aws_iam_policy_document.addon_mountpoint_s3_csi_driver.json
}

# External DNS EKS community add-on: same Route53-only policy as enable_external_dns (see external-dns-route53-policy.tf).
resource "aws_iam_role_policy" "addon_external_dns" {
  for_each = {
    for k, v in local.addon_role_config : k => v
    if k == "external-dns"
  }

  name   = "${var.name}-external-dns-addon-inline"
  role   = aws_iam_role.addon[each.key].id
  policy = data.aws_iam_policy_document.external_dns_route53.json
}
