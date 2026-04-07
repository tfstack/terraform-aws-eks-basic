################################################################################
# Karpenter — node autoscaling (terraform-aws-modules/eks/karpenter)
# Controller: Pod Identity (default). Node role + interruption queue + EventBridge.
################################################################################

check "karpenter_classic_cluster" {
  assert {
    condition     = !(var.enable_karpenter && var.enable_automode)
    error_message = "enable_karpenter requires a classic EKS cluster (enable_automode must be false)."
  }
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.3.0"

  count = var.enable_karpenter ? 1 : 0

  cluster_name      = aws_eks_cluster.this.name
  cluster_ip_family = var.cluster_ip_family
  region            = var.region
  tags              = var.tags

  namespace       = var.karpenter_namespace
  service_account = var.karpenter_service_account

  # Match upstream CloudFormation default (queue name = cluster name) for settings.interruptionQueue
  queue_name = var.name

  iam_role_use_name_prefix      = false
  iam_role_name                 = "${var.name}-karpenter-controller"
  iam_policy_use_name_prefix    = false
  iam_policy_name               = "${var.name}-karpenter-controller"
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "${var.name}-karpenter-node"

  create_pod_identity_association = false

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_openid_connect_provider.oidc_provider,
  ]
}

resource "aws_eks_pod_identity_association" "karpenter" {
  count = var.enable_karpenter && var.karpenter_identity_type == "pod_identity" ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  namespace       = var.karpenter_namespace
  service_account = var.karpenter_service_account
  role_arn        = module.karpenter[0].iam_role_arn
}

resource "aws_ec2_tag" "karpenter_subnet_discovery" {
  for_each = var.enable_karpenter ? toset(var.karpenter_discovery_subnet_ids) : toset([])

  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = aws_eks_cluster.this.name
}
