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

resource "aws_sqs_queue" "example" {
  name = "${var.cluster_name}-example-queue"
}

module "eks" {
  source = "../../"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids

  endpoint_public_access = true
  access_entries         = var.access_entries

  enable_automode     = true
  automode_node_pools = ["system", "general-purpose"]

  cloudwatch_log_group_force_destroy = true

  # Auto Mode includes CoreDNS, vpc-cni, kube-proxy, and Pod Identity Agent; do not install as addons.
  addons = {}

  # Workload IAM: SQS consumer permissions for a specific ServiceAccount.
  enable_sqs_access = true
  sqs_identity_type = "pod_identity"
  sqs_access = [
    {
      namespace       = "keda-demo"
      service_account = "keda-workload"
      queue_arns      = [aws_sqs_queue.example.arn]
      mode            = "consumer"
    }
  ]

  tags = var.tags
}

