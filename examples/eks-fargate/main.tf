terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
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

# Pure Fargate EKS cluster — no EC2 nodes. All pods run on AWS Fargate.
#
# AWS credential delivery for Fargate pods:
#   - Use IRSA (IAM Roles for Service Accounts) — annotate the service account with
#     an IAM role ARN; the pod exchanges its OIDC token with STS directly.
#   - EKS Pod Identity is NOT supported on Fargate. The Pod Identity agent is a
#     hostNetwork DaemonSet that only runs on EC2 nodes and cannot reach Fargate pods.
#     See: https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html
#
# CoreDNS note: the addon is configured with computeType = "fargate" so EKS schedules
# it on Fargate. A kube-system Fargate profile is required for this to work.
module "eks" {
  source = "../../"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)

  endpoint_public_access = true
  access_entries         = var.access_entries

  cloudwatch_log_group_force_destroy = true

  addons = {
    coredns = {
      addon_version = "v1.13.2-eksbuild.4"
      configuration_values = jsonencode({
        computeType = "fargate"
      })
    }
    vpc-cni = {
      before_compute = true
      addon_version  = "v1.21.1-eksbuild.3"
    }
  }

  fargate_profiles = {
    # Required so CoreDNS (and other kube-system pods) can schedule on Fargate.
    kube-system = {
      selectors  = [{ namespace = "kube-system" }]
      subnet_ids = module.vpc.private_subnet_ids
    }
    # Application namespace — add more selectors or profiles as needed.
    default = {
      selectors  = [{ namespace = var.fargate_namespace }]
      subnet_ids = module.vpc.private_subnet_ids
    }
  }

  tags = var.tags
}
