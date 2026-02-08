# ################################################################################
# # Data Sources
# ################################################################################

data "aws_region" "current" {}

data "aws_partition" "current" {}

# data "aws_caller_identity" "current" {
#   count = var.enable_cluster_creator_admin_permissions ? 1 : 0
# }

data "aws_caller_identity" "current" {}

# data "aws_iam_session_context" "current" {
#   count = var.enable_cluster_creator_admin_permissions ? 1 : 0
#   arn   = try(data.aws_caller_identity.current[0].arn, "")
# }

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "this" {
  count = var.create_cloudwatch_log_group ? 1 : 0

  region = var.region

  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  kms_key_id        = var.cloudwatch_log_group_kms_key_id
  log_group_class   = var.cloudwatch_log_group_class

  tags = merge(
    var.tags,
    var.cloudwatch_log_group_tags,
    { Name = "/aws/eks/${var.name}/cluster" }
  )
}

################################################################################
# KMS Key for EKS Cluster Encryption
################################################################################

data "aws_iam_policy_document" "kms_key" {
  count = var.create_kms_key ? 1 : 0

  statement {
    sid    = "Default"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "kms:*",
    ]
    resources = [
      "*",
    ]
  }

  statement {
    sid    = "KeyAdministration"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.arn]
    }

    actions = [
      "kms:CancelKeyDeletion",
      "kms:Create*",
      "kms:Delete*",
      "kms:Describe*",
      "kms:Disable*",
      "kms:Enable*",
      "kms:Get*",
      "kms:ImportKeyMaterial",
      "kms:List*",
      "kms:Put*",
      "kms:ReplicateKey",
      "kms:Revoke*",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:Update*",
    ]
    resources = [
      "*",
    ]
  }

  statement {
    sid    = "KeyUsage"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.this[0].arn]
    }

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
    ]
    resources = [
      "*",
    ]
  }
}

resource "aws_kms_key" "this" {
  count = var.create_kms_key ? 1 : 0

  description             = "${var.name} cluster encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.kms_key[0].json

  tags = merge(
    var.tags,
    { Name = "${var.name}-eks-encryption-key" }
  )
}

resource "aws_kms_alias" "this" {
  count = var.create_kms_key ? 1 : 0

  name          = "alias/eks/${var.name}"
  target_key_id = aws_kms_key.this[0].key_id
}

################################################################################
# EKS Cluster IAM Role
################################################################################

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    sid    = "EKSClusterAssumeRole"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
  }
}

resource "aws_iam_role" "this" {
  count = 1

  name_prefix           = "${var.name}-cluster-"
  path                  = "/"
  force_detach_policies = true
  max_session_duration  = 3600
  assume_role_policy    = data.aws_iam_policy_document.eks_cluster_assume_role.json
  tags                  = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = {
    AmazonEKSClusterPolicy = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  }

  role       = aws_iam_role.this[0].name
  policy_arn = each.value
}

################################################################################
# Cluster Encryption IAM Policy
################################################################################

data "aws_iam_policy_document" "this" {
  count = local.this_key_arn != null ? 1 : 0

  statement {
    sid    = "AllowClusterEncryption"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
    ]

    resources = [local.this_key_arn]
  }
}

resource "aws_iam_policy" "cluster_encryption" {
  count = local.this_key_arn != null ? 1 : 0

  name_prefix = "${var.name}-cluster-ClusterEncryption"
  description = "Cluster encryption policy to allow cluster role to utilize CMK provided"
  policy      = data.aws_iam_policy_document.this[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_encryption" {
  count = local.this_key_arn != null ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = aws_iam_policy.cluster_encryption[0].arn
}

################################################################################
# OIDC Provider for IRSA
################################################################################

data "tls_certificate" "this" {
  count = 1
  url   = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  count = 1

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.this[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge(
    var.tags,
    { Name = "${var.name}-eks-irsa" }
  )

  # Explicit dependencies to ensure proper creation order
  depends_on = [
    aws_eks_cluster.this,
    data.tls_certificate.this[0],
  ]
}

################################################################################
# EKS Cluster
################################################################################

resource "aws_eks_cluster" "this" {
  name     = var.name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.this[0].arn

  bootstrap_self_managed_addons = false

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = var.endpoint_public_access
    endpoint_private_access = true
    public_access_cidrs     = var.public_access_cidrs
  }

  kubernetes_network_config {
    ip_family         = var.cluster_ip_family
    service_ipv4_cidr = var.service_ipv4_cidr
    # service_ipv6_cidr is automatically assigned by AWS when ip_family = "ipv6"
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  access_config {
    authentication_mode = var.cluster_authentication_mode

    bootstrap_cluster_creator_admin_permissions = false
  }

  dynamic "encryption_config" {
    for_each = local.this_key_arn != null ? [1] : []
    content {
      resources = var.cluster_encryption_config_resources
      provider {
        key_arn = local.this_key_arn
      }
    }
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.this,
    aws_kms_key.this,
  ]
}

################################################################################
# Access Entries
################################################################################

resource "aws_eks_access_entry" "this" {
  for_each = var.access_entries

  region = var.region

  cluster_name      = aws_eks_cluster.this.id
  kubernetes_groups = try(each.value.kubernetes_groups, null)
  principal_arn     = each.value.principal_arn
  type              = try(each.value.type, null)
  user_name         = try(each.value.user_name, null)

  tags = merge(
    var.tags,
    try(each.value.tags, {}),
  )
}

resource "aws_eks_access_policy_association" "this" {
  for_each = { for k, v in local.flattened_access_entries : "${v.entry_key}_${v.pol_key}" => v }

  region = var.region

  access_scope {
    namespaces = each.value.association_access_scope_namespaces
    type       = each.value.association_access_scope_type
  }

  cluster_name = aws_eks_cluster.this.id

  policy_arn    = each.value.association_policy_arn
  principal_arn = each.value.principal_arn

  depends_on = [
    aws_eks_access_entry.this,
  ]
}

################################################################################
# Security Groups
################################################################################

resource "aws_security_group" "cluster" {
  count = 1

  name_prefix = "${var.name}-cluster-"
  description = "EKS cluster security group"
  vpc_id      = var.vpc_id
  region      = var.region

  tags = merge(
    var.tags,
    { Name = "${var.name}-cluster" }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "node" {
  count = 1

  name_prefix = "${var.name}-node-"
  description = "EKS node shared security group"
  vpc_id      = var.vpc_id
  region      = var.region

  tags = merge(
    var.tags,
    {
      Name                                = "${var.name}-node"
      "kubernetes.io/cluster/${var.name}" = "owned"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Security Group Rules
################################################################################

resource "aws_security_group_rule" "cluster" {
  for_each = {
    ingress_nodes_443 = {
      description              = "Node groups to cluster API"
      type                     = "ingress"
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.node[0].id
    }
  }

  description              = each.value.description
  type                     = each.value.type
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = each.value.source_security_group_id
  security_group_id        = aws_security_group.cluster[0].id
  region                   = var.region
}

resource "aws_security_group_rule" "node_cidr" {
  for_each = {
    egress_all = {
      description = "Allow all egress"
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  description       = each.value.description
  type              = each.value.type
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  security_group_id = aws_security_group.node[0].id
  region            = var.region
}

# IPv6 egress rule for node security group (when IPv6 is enabled)
resource "aws_security_group_rule" "node_ipv6_egress" {
  count = var.cluster_ip_family == "ipv6" ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.node[0].id
  region            = var.region
  description       = "Allow all IPv6 egress"
}

resource "aws_security_group_rule" "node_sg" {
  for_each = {
    ingress_cluster_10251_webhook = {
      description              = "Cluster API to node 10251/tcp webhook"
      type                     = "ingress"
      from_port                = 10251
      to_port                  = 10251
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.cluster[0].id
    }
    ingress_cluster_443 = {
      description              = "Cluster API to node groups"
      type                     = "ingress"
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.cluster[0].id
    }
    ingress_cluster_4443_webhook = {
      description              = "Cluster API to node 4443/tcp webhook"
      type                     = "ingress"
      from_port                = 4443
      to_port                  = 4443
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.cluster[0].id
    }
    ingress_cluster_6443_webhook = {
      description              = "Cluster API to node 6443/tcp webhook"
      type                     = "ingress"
      from_port                = 6443
      to_port                  = 6443
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.cluster[0].id
    }
    ingress_cluster_8443_webhook = {
      description              = "Cluster API to node 8443/tcp webhook"
      type                     = "ingress"
      from_port                = 8443
      to_port                  = 8443
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.cluster[0].id
    }
    ingress_cluster_9443_webhook = {
      description              = "Cluster API to node 9443/tcp webhook"
      type                     = "ingress"
      from_port                = 9443
      to_port                  = 9443
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.cluster[0].id
    }
    ingress_cluster_kubelet = {
      description              = "Cluster API to node kubelets"
      type                     = "ingress"
      from_port                = 10250
      to_port                  = 10250
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.cluster[0].id
    }
  }

  description              = each.value.description
  type                     = each.value.type
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = each.value.source_security_group_id
  security_group_id        = aws_security_group.node[0].id
  region                   = var.region
}

resource "aws_security_group_rule" "node_self" {
  for_each = {
    ingress_nodes_ephemeral = {
      description = "Node to node ingress on ephemeral ports"
      type        = "ingress"
      from_port   = 1025
      to_port     = 65535
      protocol    = "tcp"
    }
    ingress_self_coredns_tcp = {
      description = "Node to node CoreDNS"
      type        = "ingress"
      from_port   = 53
      to_port     = 53
      protocol    = "tcp"
    }
    ingress_self_coredns_udp = {
      description = "Node to node CoreDNS UDP"
      type        = "ingress"
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
    }
  }

  description       = each.value.description
  type              = each.value.type
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  self              = true
  security_group_id = aws_security_group.node[0].id
  region            = var.region
}

################################################################################
# Time Sleep, we need to wait for the cluster to be created and the resources to be created.
################################################################################

resource "time_sleep" "this" {
  count = 1

  create_duration = "30s"

  triggers = {
    certificate_authority_data = aws_eks_cluster.this.certificate_authority[0].data
    endpoint                   = aws_eks_cluster.this.endpoint
    kubernetes_version         = aws_eks_cluster.this.version
    name                       = aws_eks_cluster.this.name
    service_ipv4_cidr          = try(aws_eks_cluster.this.kubernetes_network_config[0].service_ipv4_cidr, null)
    service_ipv6_cidr          = try(aws_eks_cluster.this.kubernetes_network_config[0].service_ipv6_cidr, null)
    ip_family                  = try(aws_eks_cluster.this.kubernetes_network_config[0].ip_family, null)
  }

  depends_on = [
    aws_eks_cluster.this,
  ]
}

################################################################################
# Node IAM Role
################################################################################

data "aws_iam_policy_document" "eks_nodes_assume_role" {
  count = length(var.eks_managed_node_groups) > 0 ? 1 : 0

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
  count = length(var.eks_managed_node_groups) > 0 ? 1 : 0

  name               = "${var.name}-eks-nodes-role"
  assume_role_policy = data.aws_iam_policy_document.eks_nodes_assume_role[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_nodes" {
  for_each = length(var.eks_managed_node_groups) > 0 ? {
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  } : {}

  role       = aws_iam_role.eks_nodes[0].name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "eks_nodes" {
  count = length(var.eks_managed_node_groups) > 0 ? 1 : 0

  name = "${var.name}-eks-nodes-instance-profile"
  role = aws_iam_role.eks_nodes[0].name

  tags = var.tags
}

################################################################################
# Launch Templates (for metadata_options and user_data support)
################################################################################

resource "aws_launch_template" "node_group" {
  for_each = var.eks_managed_node_groups

  name_prefix = "${var.name}-${each.key}-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = each.value.disk_size
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_endpoint               = try(each.value.metadata_options.http_endpoint, "enabled")
    http_tokens                 = try(each.value.metadata_options.http_tokens, "required")
    http_put_response_hop_limit = try(each.value.metadata_options.http_put_response_hop_limit, 1)
  }

  user_data = local.node_group_user_data[each.key]

  dynamic "tag_specifications" {
    for_each = length(merge(var.tags, try(each.value.tags, {}))) > 0 ? [1] : []
    content {
      resource_type = "instance"
      tags          = merge(var.tags, try(each.value.tags, {}))
    }
  }

  tags = merge(var.tags, try(each.value.tags, {}))

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_instance_profile.eks_nodes
  ]
}

################################################################################
# EKS Managed Node Groups
################################################################################

resource "aws_eks_node_group" "this" {
  for_each = var.eks_managed_node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = try(each.value.name, "${var.name}-${each.key}")
  node_role_arn   = aws_iam_role.eks_nodes[0].arn
  subnet_ids      = try(each.value.subnet_ids, null) != null ? each.value.subnet_ids : var.subnet_ids

  instance_types = each.value.instance_types
  ami_type       = each.value.ami_type
  # disk_size is specified in launch template when using launch templates

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  update_config {
    max_unavailable = 1
  }

  dynamic "remote_access" {
    for_each = try(each.value.remote_access, null) != null ? [each.value.remote_access] : []
    content {
      ec2_ssh_key               = try(remote_access.value.ec2_ssh_key, null)
      source_security_group_ids = try(remote_access.value.source_security_group_ids, null)
    }
  }

  # Always use launch template for user_data support
  launch_template {
    id      = aws_launch_template.node_group[each.key].id
    version = aws_launch_template.node_group[each.key].latest_version
  }

  labels = try(each.value.labels, {})
  tags   = merge(var.tags, try(each.value.tags, {}))

  timeouts {
    create = "60m"
    update = "60m"
    delete = "30m"
  }

  lifecycle {
    create_before_destroy = false
    ignore_changes = [
      scaling_config[0].desired_size,
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_nodes,
    time_sleep.this,
    aws_eks_addon.before_compute
  ]
}

################################################################################
# EKS Addons
################################################################################

# Local values to determine service account role ARN for addons
locals {
  addon_service_account_role_arns = {
    for k, v in var.addons : k => (
      try(v.service_account_role_arn, null) != null
      ? v.service_account_role_arn
      : try(aws_iam_role.addon[k].arn, null)
    )
  }
}

# Addons that need to be created before node groups (before_compute = true)
resource "aws_eks_addon" "before_compute" {
  for_each = {
    for k, v in var.addons : k => v
    if try(v.before_compute, false)
  }

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = try(each.value.addon_version, null)
  resolve_conflicts_on_create = try(each.value.resolve_conflicts_on_create, "OVERWRITE")
  resolve_conflicts_on_update = try(each.value.resolve_conflicts_on_update, "OVERWRITE")
  configuration_values        = try(each.value.configuration_values, null)
  service_account_role_arn    = try(local.addon_service_account_role_arns[each.key], null)

  tags = var.tags

  depends_on = [
    time_sleep.this,
    aws_iam_role.addon
  ]
}

# Addons that can be created after node groups (default behavior)
resource "aws_eks_addon" "this" {
  for_each = {
    for k, v in var.addons : k => v
    if !try(v.before_compute, false)
  }

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = try(each.value.addon_version, null)
  resolve_conflicts_on_create = try(each.value.resolve_conflicts_on_create, "OVERWRITE")
  resolve_conflicts_on_update = try(each.value.resolve_conflicts_on_update, "OVERWRITE")
  configuration_values        = try(each.value.configuration_values, null)
  service_account_role_arn    = try(local.addon_service_account_role_arns[each.key], null)

  tags = var.tags

  depends_on = [
    time_sleep.this,
    aws_eks_node_group.this,
    aws_iam_role.addon
  ]
}
