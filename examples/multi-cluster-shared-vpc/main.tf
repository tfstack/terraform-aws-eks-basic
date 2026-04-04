terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# Fargate and Auto Mode cluster subnet tags merged into vpc tags so aws_subnet owns them.
# aws_ec2_tag would conflict with aws_subnet in AWS provider v6 (both fighting over the same tag keys).
#
# EBS / kube-infra: name the classic cluster and Auto Mode cluster to match
# kube-infra `infrastructure/aws-ebs-csi-driver/overlays/<cluster>` (this example uses
# classic = eks-1 → vendored CSI + ebs.csi.aws.com; automode = eks-2 → ebs.csi.eks.amazonaws.com).
locals {
  vpc_tags = merge(var.tags, {
    "kubernetes.io/cluster/${var.cluster_names.fargate}"  = "shared"
    "kubernetes.io/cluster/${var.cluster_names.automode}" = "shared"
  })

  ack_kro_capabilities = {
    ack = {
      iam_policy_arns = {
        sqs = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
      }
    }
    kro = {}
  }

  sqs_access_queue_arn = {
    classic  = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.cluster_names.classic}-celery-jobs"
    fargate  = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.cluster_names.fargate}-celery-jobs"
    automode = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.cluster_names.automode}-celery-jobs"
  }

  sqs_access_queue_arn_dlq = {
    classic  = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.cluster_names.classic}-celery-jobs-dlq"
    fargate  = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.cluster_names.fargate}-celery-jobs-dlq"
    automode = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.cluster_names.automode}-celery-jobs-dlq"
  }
}

# One VPC for three clusters. enable_eks_tags adds kubernetes.io/cluster/<classic>=shared via eks_cluster_name.
# The extra fargate/automode cluster tags come from local.vpc_tags above.
module "vpc" {
  source = "cloudbuildlab/vpc/aws"

  vpc_name           = var.vpc_name
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]

  create_igw       = true
  nat_gateway_type = "single"

  enable_eks_tags  = true
  eks_cluster_name = var.cluster_names.classic
  tags             = local.vpc_tags
}

# ── Classic EC2 managed node groups ───────────────────────────────────────────
module "eks_classic" {
  source = "../../"

  name               = var.cluster_names.classic
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)

  endpoint_public_access = var.endpoint_public_access
  public_access_cidrs    = var.public_access_cidrs
  private_access_cidrs   = var.private_access_cidrs

  access_entries                           = var.access_entries_classic
  enable_cluster_creator_admin_permissions = true
  cloudwatch_log_group_force_destroy       = true

  addons = {
    coredns = { addon_version = "v1.13.2-eksbuild.4" }
    eks-pod-identity-agent = {
      before_compute = true
      addon_version  = "v1.3.10-eksbuild.2"
    }
    kube-proxy = { addon_version = "v1.35.3-eksbuild.2" }
    vpc-cni = {
      before_compute = true
      addon_version  = "v1.21.1-eksbuild.7"
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
        nodeAgent           = { enablePolicyEventLogs = "true" }
      })
    }
  }

  eks_managed_node_groups = {
    one = {
      name           = "ng-1"
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3a.large"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }
    }
  }

  capabilities = merge(
    local.ack_kro_capabilities,
    var.argocd_idc_instance_arn != null ? {
      argocd = {
        access_entry_policy_associations = [{
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }]
        configuration = {
          argo_cd = {
            namespace         = "argocd"
            aws_idc           = { idc_instance_arn = var.argocd_idc_instance_arn, idc_region = var.aws_region }
            rbac_role_mapping = var.argocd_rbac_role_mappings
            network_access    = { vpce_ids = var.argocd_vpce_ids }
          }
        }
      }
    } : {}
  )

  ebs_csi_driver_identity_type = "pod_identity"
  enable_ebs_csi_driver        = true

  enable_secrets_manager        = true
  secrets_manager_identity_type = "pod_identity"
  secrets_manager_associations = [
    { namespace = "sm-operator-system", service_account = "awssm-sync" },
  ]
  secrets_manager_secret_name_prefixes = ["bitwarden/sm-operator"]

  enable_sqs_access = true
  sqs_identity_type = "pod_identity"
  sqs_access = [
    {
      namespace       = "celery"
      service_account = "celery-workload"
      queue_arns = [
        local.sqs_access_queue_arn.classic,
        local.sqs_access_queue_arn_dlq.classic,
      ]
      mode = "consumer"
    },
    {
      namespace       = "keda"
      service_account = "keda-operator"
      queue_arns      = [local.sqs_access_queue_arn.classic]
      mode            = "read_only"
    },
  ]

  tags = var.tags
}

# ── Fargate only ─────────────────────────────────────────────────────────────
module "eks_fargate" {
  source = "../../"

  name               = var.cluster_names.fargate
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)

  endpoint_public_access = var.endpoint_public_access
  public_access_cidrs    = var.public_access_cidrs
  private_access_cidrs   = var.private_access_cidrs

  access_entries                           = var.access_entries_fargate
  enable_cluster_creator_admin_permissions = true
  cloudwatch_log_group_force_destroy       = true

  addons = {
    coredns = {
      addon_version        = "v1.13.2-eksbuild.4"
      configuration_values = jsonencode({ computeType = "fargate" })
    }
    vpc-cni = {
      before_compute = true
      addon_version  = "v1.21.1-eksbuild.7"
    }
    eks-pod-identity-agent = {
      before_compute = true
      addon_version  = "v1.3.10-eksbuild.2"
    }
  }

  # Per-namespace profiles (Fargate matches namespace only, not labels, unless you add selectors).
  # When argocd_idc_instance_arn is set, the module installs Argo CD into namespace "argocd" on this
  # cluster — without an argocd profile, those pods stay Pending on Fargate-only.
  fargate_profiles = merge(
    {
      kube-system = {
        selectors  = [{ namespace = "kube-system" }]
        subnet_ids = module.vpc.private_subnet_ids
      }
      aws-load-balancer-controller = {
        selectors  = [{ namespace = "aws-load-balancer-controller" }]
        subnet_ids = module.vpc.private_subnet_ids
      }
      gatekeeper-system = {
        selectors  = [{ namespace = "gatekeeper-system" }]
        subnet_ids = module.vpc.private_subnet_ids
      }
      keda = {
        selectors  = [{ namespace = "keda" }]
        subnet_ids = module.vpc.private_subnet_ids
      }
      workload_sqs = {
        selectors  = [{ namespace = "celery" }]
        subnet_ids = module.vpc.private_subnet_ids
      }
      default = {
        selectors  = [{ namespace = var.fargate_namespace }]
        subnet_ids = module.vpc.private_subnet_ids
      }
    },
    var.argocd_idc_instance_arn != null ? {
      argocd = {
        selectors  = [{ namespace = "argocd" }]
        subnet_ids = module.vpc.private_subnet_ids
      }
    } : {}
  )

  enable_aws_load_balancer_controller        = true
  aws_load_balancer_controller_identity_type = "irsa"

  capabilities = merge(
    local.ack_kro_capabilities,
    var.argocd_idc_instance_arn != null ? {
      argocd = {
        access_entry_policy_associations = [{
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }]
        configuration = {
          argo_cd = {
            namespace         = "argocd"
            aws_idc           = { idc_instance_arn = var.argocd_idc_instance_arn, idc_region = var.aws_region }
            rbac_role_mapping = var.argocd_rbac_role_mappings
            network_access    = { vpce_ids = var.argocd_vpce_ids }
          }
        }
      }
    } : {}
  )

  # Fargate: EKS Pod Identity is not supported for pods on Fargate (AWS). Use IRSA for SQS roles
  # and annotate ServiceAccounts (kube-devops-apps celery SA; kube-infra keda-operator SA on eks-3).
  enable_sqs_access = true
  sqs_identity_type = "irsa"
  sqs_access = [
    {
      namespace       = "celery"
      service_account = "celery-workload"
      queue_arns = [
        local.sqs_access_queue_arn.fargate,
        local.sqs_access_queue_arn_dlq.fargate,
      ]
      mode = "consumer"
    },
    {
      namespace       = "keda"
      service_account = "keda-operator"
      queue_arns      = [local.sqs_access_queue_arn.fargate]
      mode            = "read_only"
    },
  ]

  tags = var.tags
}

# ── Auto Mode ───────────────────────────────────────────────────────────────
module "eks_automode" {
  source = "../../"

  name               = var.cluster_names.automode
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids

  endpoint_public_access = var.endpoint_public_access
  public_access_cidrs    = var.public_access_cidrs
  private_access_cidrs   = var.private_access_cidrs

  access_entries                           = var.access_entries_automode
  enable_cluster_creator_admin_permissions = true
  cloudwatch_log_group_force_destroy       = true

  enable_automode     = true
  automode_node_pools = ["system", "general-purpose"]
  addons              = {}

  capabilities = merge(
    local.ack_kro_capabilities,
    var.argocd_idc_instance_arn != null ? {
      argocd = {
        access_entry_policy_associations = [{
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }]
        configuration = {
          argo_cd = {
            namespace         = "argocd"
            aws_idc           = { idc_instance_arn = var.argocd_idc_instance_arn, idc_region = var.aws_region }
            rbac_role_mapping = var.argocd_rbac_role_mappings
            network_access    = { vpce_ids = var.argocd_vpce_ids }
          }
        }
      }
    } : {}
  )

  ebs_csi_driver_identity_type = "pod_identity"
  enable_ebs_csi_driver        = true

  enable_secrets_manager        = true
  secrets_manager_identity_type = "pod_identity"
  secrets_manager_associations = [
    { namespace = "sm-operator-system", service_account = "awssm-sync" },
  ]
  secrets_manager_secret_name_prefixes = ["bitwarden/sm-operator"]

  enable_sqs_access = true
  sqs_identity_type = "pod_identity"
  sqs_access = [
    {
      namespace       = "celery"
      service_account = "celery-workload"
      queue_arns = [
        local.sqs_access_queue_arn.automode,
        local.sqs_access_queue_arn_dlq.automode,
      ]
      mode = "consumer"
    },
    {
      namespace       = "keda"
      service_account = "keda-operator"
      queue_arns      = [local.sqs_access_queue_arn.automode]
      mode            = "read_only"
    },
  ]

  tags = var.tags
}

# ── CodeConnections: one per cluster (separate Argo CD capability roles) ────
module "argocd_connections_classic" {
  source = "../../modules/argocd-codeconnections"
  count  = var.argocd_idc_instance_arn != null ? 1 : 0

  argocd_capability_role_name = module.eks_classic.cluster_capability_role_names["argocd"]
  connections = [
    { name = "github-${var.cluster_names.classic}", provider_type = "GitHub" }
  ]
  tags = var.tags
}

module "argocd_connections_fargate" {
  source = "../../modules/argocd-codeconnections"
  count  = var.argocd_idc_instance_arn != null ? 1 : 0

  argocd_capability_role_name = module.eks_fargate.cluster_capability_role_names["argocd"]
  connections = [
    { name = "github-${var.cluster_names.fargate}", provider_type = "GitHub" }
  ]
  tags = var.tags
}

module "argocd_connections_automode" {
  source = "../../modules/argocd-codeconnections"
  count  = var.argocd_idc_instance_arn != null ? 1 : 0

  argocd_capability_role_name = module.eks_automode.cluster_capability_role_names["argocd"]
  connections = [
    { name = "github-${var.cluster_names.automode}", provider_type = "GitHub" }
  ]
  tags = var.tags
}
