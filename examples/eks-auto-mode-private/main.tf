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

# EKS cluster with Auto Mode on an existing VPC (no VPC module; pass vpc_id and subnet_ids).
module "eks" {
  source = "../../"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids

  endpoint_public_access = false # Private-only; API reachable only from within the VPC (or VPN)
  private_access_cidrs   = var.private_access_cidrs

  access_entries = var.access_entries

  enable_automode     = true
  automode_node_pools = ["system", "general-purpose"]

  cloudwatch_log_group_force_destroy = true
  addons                             = {}

  # Capabilities: ACK, KRO; Argo CD when argocd_idc_instance_arn is set.
  capabilities = merge(
    {
      ack = {}
      kro = {}
    },
    var.argocd_idc_instance_arn != null ? {
      argocd = {
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
    } : {}
  )

  ebs_csi_driver_identity_type = "pod_identity"
  enable_ebs_csi_driver        = true

  tags = var.tags
}

# CodeConnections for Argo CD repo access (GitHub).
module "argocd_connections" {
  source = "../../modules/argocd-codeconnections"

  count = var.argocd_idc_instance_arn != null ? 1 : 0

  argocd_capability_role_arn = module.eks.cluster_capability_role_arns["argocd"]

  connections = [
    { name = "github", provider_type = "GitHub" }
  ]

  tags = var.tags
}
