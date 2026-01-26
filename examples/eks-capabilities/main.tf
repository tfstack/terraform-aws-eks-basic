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
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
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

  # Enable Internet Gateway & NAT Gateway
  create_igw       = true
  nat_gateway_type = "single"

  enable_eks_tags  = true
  eks_cluster_name = local.name

  tags = local.tags
}

# IAM policy to allow ACK to manage Pod Identity Associations
resource "aws_iam_policy" "ack_eks_pod_identity" {
  name        = "${var.cluster_name}-ack-eks-pod-identity"
  description = "Permissions for ACK to manage EKS Pod Identity Associations"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:CreatePodIdentityAssociation",
          "eks:DeletePodIdentityAssociation",
          "eks:DescribePodIdentityAssociation",
          "eks:ListPodIdentityAssociations",
          "eks:TagResource",
          "eks:UntagResource",
          "eks:ListTagsForResource",
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# EKS cluster with all three capabilities enabled
module "eks" {
  source = "../../"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  node_subnet_ids = module.vpc.private_subnet_ids

  # Use EC2 compute mode
  compute_mode = ["ec2"]

  # EC2 Node Group Configuration
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_disk_size      = var.node_disk_size

  # Enable EKS Capabilities
  enable_ack_capability = var.enable_ack_capability
  ack_capability_iam_policy_arns = {
    s3           = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    dynamodb     = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
    iam          = "arn:aws:iam::aws:policy/IAMFullAccess"
    pod_identity = aws_iam_policy.ack_eks_pod_identity.arn
  }
  enable_kro_capability    = var.enable_kro_capability
  kro_capability_role_arn  = var.kro_capability_role_arn
  enable_argocd_capability = var.enable_argocd_capability

  # Optional: Enable EBS CSI Driver for persistent volumes
  enable_ebs_csi_driver = var.enable_ebs_csi_driver

  # Enable Pod Identity Agent for AWS SDK credentials in pods
  enable_pod_identity_agent = var.enable_pod_identity_agent

  # Cluster admin access entries
  cluster_admin_arns = var.cluster_admin_arns

  tags = var.tags

  # Explicitly depend on the VPC module to ensure all its resources are created before the EKS cluster
  depends_on = [module.vpc]
}
