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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
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

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_ca_certificate
  token                  = module.eks.cluster_auth_token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = module.eks.cluster_ca_certificate
    token                  = module.eks.cluster_auth_token
  }
}

locals {
  base_name = var.cluster_name
  name      = var.cluster_name
  tags      = var.tags
}

module "vpc" {
  source = "cloudbuildlab/vpc/aws"

  vpc_name           = local.base_name
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]

  create_igw       = true
  nat_gateway_type = "single"

  enable_eks_tags  = true
  eks_cluster_name = local.name

  tags = local.tags
}

# Example: EKS cluster using Pod Identity for ALB controller, External DNS, and EBS CSI addon
module "eks" {
  source = "../../"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)

  endpoint_public_access = true

  # So the Terraform runner can create kubernetes_namespace, kubernetes_service_account, kubernetes_deployment
  enable_cluster_creator_admin_permissions = true
  access_entries                           = var.access_entries

  # Required when using Pod Identity: enable eks-pod-identity-agent addon
  addons = {
    coredns = {
      addon_version = "v1.13.2-eksbuild.1"
    }
    eks-pod-identity-agent = {
      before_compute = true
      addon_version  = "v1.3.10-eksbuild.2"
    }
    kube-proxy = {
      addon_version = "v1.35.0-eksbuild.2"
    }
    vpc-cni = {
      before_compute = true
      addon_version  = "v1.21.1-eksbuild.3"
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
        nodeAgent = {
          enablePolicyEventLogs = "true"
        }
      })
    }
  }

  # Pod Identity for AWS Load Balancer Controller
  aws_load_balancer_controller_identity_type = "pod_identity"
  enable_aws_load_balancer_controller        = true

  # Pod Identity for External DNS
  external_dns_identity_type = "pod_identity"
  enable_external_dns        = true

  # Pod Identity for EBS CSI driver
  ebs_csi_driver_identity_type = "pod_identity"
  enable_ebs_csi_driver        = true

  # Pod Identity for addons (EBS CSI driver)
  addon_identity_type = "pod_identity"
  addon_service_accounts = {
    "aws-ebs-csi-driver" = {
      namespace = "kube-system"
      name      = "ebs-csi-controller-sa"
    }
  }

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

  eks_managed_node_groups = {
    one = {
      name           = "node-group-1"
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3a.large"]

      min_size     = 3
      max_size     = 3
      desired_size = 3

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }
    }
  }
}
