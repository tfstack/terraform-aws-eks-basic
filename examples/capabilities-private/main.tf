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
  # Requires VPC module with eks_endpoint_allowed_cidrs (e.g. cloudbuildlab/vpc/aws after release, or a local path).
  source = "cloudbuildlab/vpc/aws"

  vpc_name           = var.cluster_name
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]

  create_igw       = true
  nat_gateway_type = "single"

  enable_eks_tags                  = true
  eks_cluster_name                 = var.cluster_name
  enable_eks_endpoint              = true
  enable_eks_auth_endpoint         = true
  enable_eks_capabilities_endpoint = true
  tags                             = var.tags
}

# EKS capabilities (Argo CD) VPC endpoint is created by the VPC module. See VPC_MODULE_EKS_ENDPOINT_CIDRS.md.

# EKS cluster with all three EKS capabilities: ACK, KRO, and Argo CD
module "eks" {
  source = "../../"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids

  endpoint_public_access = false # Private-only; EKS API and Argo CD reachable only from within the VPC

  # So the Terraform runner can create kubernetes_namespace, kubernetes_service_account, kubernetes_deployment
  enable_cluster_creator_admin_permissions = true
  access_entries                           = var.access_entries

  cloudwatch_log_group_force_destroy = true

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

  # EKS Capabilities (ACK, KRO, optional Argo CD). Cluster auth mode defaults to API_AND_CONFIG_MAP when capabilities are set.
  # Argo CD is only included when argocd_idc_instance_arn is set (Identity Center required by AWS).
  capabilities = merge(
    {
      # AWS Controllers for Kubernetes – attach IAM policies for controllers (e.g. S3).
      # Example uses broad policy for simplicity; use least-privilege or IAM Role Selectors in production (https://docs.aws.amazon.com/eks/latest/userguide/ack-permissions.html).
      ack = {
        iam_policy_arns = {
          s3 = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
        }
      }
      # Kube Resource Orchestrator
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
              vpce_ids = [module.vpc.vpc_endpoint_ids["eks_capabilities"]]
            }
          }
        }
      }
    } : {}
  )

  eks_managed_node_groups = {
    one = {
      name           = "node-group-1"
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }
  }

  depends_on = [
    module.vpc
  ]
}
