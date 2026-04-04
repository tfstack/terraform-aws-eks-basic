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

# Minimal EKS Auto Mode cluster — BYO VPC and subnets.
# No capabilities, no Argo CD, no Secrets Manager, no EBS CSI.
# Use this as a starting point; add features from the auto-mode example as needed.
module "eks" {
  source = "../../"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids

  endpoint_public_access = true

  enable_automode     = true
  automode_node_pools = ["system", "general-purpose"]

  # Auto Mode has built-in addons; do not install CoreDNS, vpc-cni, kube-proxy, or Pod Identity Agent here.
  addons = {}

  tags = var.tags
}
