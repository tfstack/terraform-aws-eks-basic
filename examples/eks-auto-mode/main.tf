terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
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

module "vpc" {
  source = "cloudbuildlab/vpc/aws"

  vpc_name           = var.cluster_name
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]

  create_igw       = true
  nat_gateway_type = "single"

  enable_eks_tags  = true
  eks_cluster_name = var.cluster_name
  tags             = var.tags
}

# EKS cluster with Auto Mode (no managed node groups; compute is auto-provisioned)
module "eks" {
  source = "../../"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version
  vpc_id             = module.vpc.vpc_id

  subnet_ids = module.vpc.private_subnet_ids

  endpoint_public_access = true
  access_entries         = var.access_entries

  enable_automode     = true
  automode_node_pools = ["system", "general-purpose"]
  # eks_managed_node_groups not set (mutually exclusive with enable_automode)

  cloudwatch_log_group_force_destroy = true

  # CoreDNS, vpc-cni, kube-proxy, and Pod Identity Agent are built into Auto Mode; do not install as addons.
  addons = {}

  # Pod Identity works out of the box on Auto Mode (agent is included). E.g. EBS CSI driver:
  ebs_csi_driver_identity_type = "pod_identity"
  enable_ebs_csi_driver        = true

  # Pod Identity for Secrets Manager (for app pods mounting secrets via Secrets Store CSI Driver)
  # sm-operator: awssm-sync SA in sm-operator-system fetches Bitwarden token from AWS Secrets Manager
  # atlantis-1: awssm-sync SA in atlantis-1 fetches Bitwarden token from bitwarden/sm-operator/atlantis-1/*
  enable_secrets_manager        = true
  secrets_manager_identity_type = "pod_identity"
  secrets_manager_associations = [
    { namespace = "sm-operator-system", service_account = "awssm-sync" },
    { namespace = "atlantis-1", service_account = "awssm-sync" }
  ]
  secrets_manager_secret_name_prefixes = ["bitwarden/sm-operator"]

  tags = var.tags
}
