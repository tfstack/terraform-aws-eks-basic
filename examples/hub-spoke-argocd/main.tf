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

# Spoke cluster names need kubernetes.io/cluster tags on subnets (shared VPC + Auto Mode).
# aws_ec2_tag would conflict with aws_subnet in AWS provider v6.
#
# The spoke access_entries reference module.eks_hub.cluster_capability_role_arns["argocd"] (computed).
# Terraform resolves this dependency automatically: hub IAM role is created first,
# then spoke access entries are applied.
locals {
  vpc_tags = merge(var.tags, {
    "kubernetes.io/cluster/${var.cluster_names.spoke_dev}"  = "shared"
    "kubernetes.io/cluster/${var.cluster_names.spoke_prod}" = "shared"
  })
}

# ── Shared VPC ────────────────────────────────────────────────────────────────
module "vpc" {
  source = "cloudbuildlab/vpc/aws"

  vpc_name           = var.vpc_name
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  create_igw       = true
  nat_gateway_type = "single"

  # Hub cluster name drives the primary kubernetes.io/cluster/* subnet tag.
  # Spoke cluster tags are merged in local.vpc_tags above.
  enable_eks_tags  = true
  eks_cluster_name = var.cluster_names.hub

  tags = local.vpc_tags
}

# ── Hub EKS Cluster (Argo CD) ─────────────────────────────────────────────────
# The hub runs the managed Argo CD capability and deploys to spoke clusters via
# the hub Argo CD role, which is granted cluster-admin on each spoke's access_entries.
module "eks_hub" {
  source = "../../"

  name               = var.cluster_names.hub
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  endpoint_public_access = var.endpoint_public_access
  public_access_cidrs    = var.public_access_cidrs
  private_access_cidrs   = var.private_access_cidrs

  access_entries                     = var.access_entries_hub
  cloudwatch_log_group_force_destroy = true

  # Auto Mode: no managed node groups; CoreDNS, vpc-cni, kube-proxy, Pod Identity Agent are built in.
  enable_automode     = true
  automode_node_pools = ["system", "general-purpose"]
  addons              = {}

  ebs_csi_driver_identity_type = "pod_identity"
  enable_ebs_csi_driver        = true

  # ── EKS Capabilities ────────────────────────────────────────────────────────
  # Hub has ACK, KRO, and Argo CD. Spoke clusters have ACK and KRO only.
  # access_entry_policy_associations gives the Argo CD role admin access to
  # the hub cluster itself (in-cluster deployments or App of Apps on the hub).
  # ──────────────────────────────────────────────────────────────────────────
  capabilities = {
    ack = {}
    kro = {}
    argocd = {
      access_entry_policy_associations = [
        {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      ]
      configuration = {
        argo_cd = {
          namespace = "argocd"
          aws_idc = {
            idc_instance_arn = var.argocd_idc_instance_arn
            idc_region       = var.aws_region
          }
          rbac_role_mapping = var.argocd_rbac_role_mappings
          network_access = {
            vpce_ids = var.argocd_vpce_ids
          }
        }
      }
    }
  }

  tags = var.tags
}

# ── Spoke 1 ────────────────────────────────────────────────────────────────────
# No Argo CD capability. Grants hub Argo CD role cluster-admin so Argo CD can
# deploy workloads here. The argocd_hub key is static; only the value is computed.
module "eks_spoke_1" {
  source = "../../"

  name               = var.cluster_names.spoke_dev
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  endpoint_public_access = var.endpoint_public_access
  public_access_cidrs    = var.public_access_cidrs
  private_access_cidrs   = var.private_access_cidrs

  access_entries = merge(var.access_entries_spoke_dev, {
    argocd_hub = {
      principal_arn = module.eks_hub.cluster_capability_role_arns["argocd"]
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  })

  cloudwatch_log_group_force_destroy = true

  enable_automode     = true
  automode_node_pools = ["system", "general-purpose"]
  addons              = {}

  ebs_csi_driver_identity_type = "pod_identity"
  enable_ebs_csi_driver        = true

  capabilities = {
    ack = {}
    kro = {}
  }

  tags = var.tags
}

# ── Spoke 2 ────────────────────────────────────────────────────────────────────
module "eks_spoke_2" {
  source = "../../"

  name               = var.cluster_names.spoke_prod
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  endpoint_public_access = var.endpoint_public_access
  public_access_cidrs    = var.public_access_cidrs
  private_access_cidrs   = var.private_access_cidrs

  access_entries = merge(var.access_entries_spoke_prod, {
    argocd_hub = {
      principal_arn = module.eks_hub.cluster_capability_role_arns["argocd"]
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  })

  cloudwatch_log_group_force_destroy = true

  enable_automode     = true
  automode_node_pools = ["system", "general-purpose"]
  addons              = {}

  ebs_csi_driver_identity_type = "pod_identity"
  enable_ebs_csi_driver        = true

  capabilities = {
    ack = {}
    kro = {}
  }

  tags = var.tags
}

# ── Argo CD CodeConnections (GitHub) ─────────────────────────────────────────
# Hub only: spoke clusters do not host Argo CD and need no CodeConnections.
#
# IMPORTANT: Only connections listed here are permitted in the IAM policy.
# Argo CD Application repoURLs must use the UUID from output argocd_connection_ids["<name>"].
# Using any other connection UUID will cause AccessDeniedException in Argo CD.
#
# After apply: complete the GitHub OAuth handshake in the AWS Console — new
# connections start PENDING until authorised.
# ─────────────────────────────────────────────────────────────────────────────
module "argocd_connections" {
  source = "../../modules/argocd-codeconnections"

  argocd_capability_role_name = module.eks_hub.cluster_capability_role_names["argocd"]

  connections = [
    { name = "github-${var.cluster_names.hub}", provider_type = "GitHub" }
  ]

  tags = var.tags
}
