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
  aws_lb_controller_namespace                = "aws-load-balancer-controller"
  aws_lb_controller_service_account          = "aws-load-balancer-controller"

  # Pod Identity for External DNS
  external_dns_identity_type   = "pod_identity"
  enable_external_dns          = true
  external_dns_namespace       = "external-dns"
  external_dns_service_account = "external-dns"

  # Pod Identity for addons (EBS CSI driver)
  addon_identity_type = "pod_identity"
  addon_service_accounts = {
    "aws-ebs-csi-driver" = {
      namespace = "kube-system"
      name      = "ebs-csi-controller-sa"
    }
  }

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

resource "kubernetes_namespace" "external_dns" {
  metadata {
    name   = "external-dns"
    labels = { name = "external-dns" }
  }
  lifecycle { ignore_changes = [metadata[0].annotations, metadata[0].labels] }
  depends_on = [module.eks]
}

resource "kubernetes_service_account" "external_dns" {
  metadata {
    name      = "external-dns"
    namespace = kubernetes_namespace.external_dns.metadata[0].name
  }
  lifecycle { ignore_changes = [metadata[0].annotations, metadata[0].labels] }
  depends_on = [module.eks]
}

locals {
  external_dns_args = concat(
    ["--provider=aws", "--policy=sync", "--log-level=info", "--log-format=text", "--source=service", "--source=ingress", "--registry=txt"],
    var.external_dns_domain_filter != "" ? ["--domain-filter=${var.external_dns_domain_filter}"] : [],
    var.external_dns_txt_owner_id != "" ? ["--txt-owner-id=${var.external_dns_txt_owner_id}"] : [],
    ["--aws-zone-type=${var.external_dns_aws_zone_type}"]
  )
}

resource "kubernetes_deployment" "external_dns" {
  metadata {
    name      = "external-dns"
    namespace = kubernetes_namespace.external_dns.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "external-dns" }
    }
    template {
      metadata { labels = { app = "external-dns" } }
      spec {
        service_account_name = kubernetes_service_account.external_dns.metadata[0].name
        container {
          name  = "external-dns"
          image = "registry.k8s.io/external-dns/external-dns:v0.20.0"
          args  = local.external_dns_args
          env {
            name  = "AWS_DEFAULT_REGION"
            value = var.aws_region
          }
          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }
        }
      }
    }
  }
  lifecycle { ignore_changes = [metadata[0].annotations, metadata[0].labels] }
  depends_on = [kubernetes_service_account.external_dns]
}
