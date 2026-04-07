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

# Classic EKS — EC2 managed node groups. Use when Auto Mode is not available
# or when you need full control over node configuration (instance types, AMIs, etc.).
#
# Pod Identity is supported on EC2 nodes (Pod Identity agent addon required).
# Mutually exclusive with enable_automode.
module "eks" {
  source = "../../"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)

  # ── API Endpoint Access ──────────────────────────────────────────────────────
  # Public (default): API reachable over the internet.
  #   endpoint_public_access = true
  #   public_access_cidrs    = ["0.0.0.0/0"]  # tighten to your egress IP in production
  #
  # Private-only: API only reachable from within the VPC or via VPN.
  #   endpoint_public_access = false
  #   private_access_cidrs   = ["10.0.0.0/8"]
  #   (Terraform runner must be inside the VPC or connected via VPN)
  #
  # Both (recommended for production):
  #   endpoint_public_access = true
  #   public_access_cidrs    = ["1.2.3.4/32"]  # your egress IP only
  #   private_access_cidrs   = ["10.0.0.0/8"]
  # ────────────────────────────────────────────────────────────────────────────
  endpoint_public_access = var.endpoint_public_access
  public_access_cidrs    = var.public_access_cidrs
  private_access_cidrs   = var.private_access_cidrs

  access_entries = var.access_entries

  enable_cluster_creator_admin_permissions = true

  cloudwatch_log_group_force_destroy = true

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

  eks_managed_node_groups = {
    one = {
      name           = "node-group-1"
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3a.large"]

      min_size     = 2
      max_size     = 4
      desired_size = 2

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }
    }
  }

  # ── EKS Capabilities (ACK, KRO, Argo CD) ────────────────────────────────────
  # ACK and KRO are always enabled.
  # Argo CD is enabled only when argocd_idc_instance_arn is set
  # (AWS IAM Identity Center is required by the EKS Argo CD capability).
  #
  # To enable Argo CD, set in terraform.tfvars:
  #   argocd_idc_instance_arn   = "arn:aws:sso:::instance/ssoins-xxxxxxxxxxxx"
  #   argocd_rbac_role_mappings = [{ role = "ADMIN", identity = [{ type = "SSO_USER", id = "..." }] }]
  #
  # Argo CD UI endpoint (argocd_vpce_ids):
  #   Leave empty [] for a publicly reachable Argo CD UI.
  #   Set a VPC interface endpoint ID to restrict access to within the VPC.
  #
  # KNOWN BUG — Argo CD public ↔ private UI switching does not apply in-place.
  #   Workaround: remove argocd from capabilities, apply (destroys it), then re-add
  #   with the correct argocd_vpce_ids and apply again.
  #   Note: argocd_vpce_ids controls the Argo CD UI only — NOT the Kubernetes API endpoint.
  # ────────────────────────────────────────────────────────────────────────────
  capabilities = merge(
    {
      ack = {}
      kro = {}
    },
    var.argocd_idc_instance_arn != null ? {
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
    } : {}
  )

  # ── EBS CSI Driver (Pod Identity) ───────────────────────────────────────────
  # Pod Identity is supported on EC2 nodes (eks-pod-identity-agent addon above is required).
  # ────────────────────────────────────────────────────────────────────────────
  ebs_csi_driver_identity_type = "pod_identity"
  enable_ebs_csi_driver        = true

  # ── Cluster Autoscaler (Pod Identity) ───────────────────────────────────────
  # IAM for in-cluster Cluster Autoscaler (GitOps manifest). EC2 managed node
  # groups only — not for Auto Mode or Fargate. Requires eks-pod-identity-agent.
  # ────────────────────────────────────────────────────────────────────────────
  enable_cluster_autoscaler_iam    = true
  cluster_autoscaler_identity_type = "pod_identity"

  # ── Secrets Manager (Pod Identity) ──────────────────────────────────────────
  # Grants named service accounts access to Secrets Manager via Pod Identity.
  # Pod Identity is supported on EC2 nodes; NOT supported on Fargate (use IRSA there).
  # Remove this block if not using Secrets Store CSI Driver.
  # ────────────────────────────────────────────────────────────────────────────
  enable_secrets_manager        = true
  secrets_manager_identity_type = "pod_identity"
  secrets_manager_associations = [
    { namespace = "sm-operator-system", service_account = "awssm-sync" },
  ]
  secrets_manager_secret_name_prefixes = ["bitwarden/sm-operator"]

  tags = var.tags
}

# ── Argo CD CodeConnections (GitHub) ─────────────────────────────────────────
# Creates a GitHub CodeConnection and grants UseConnection + GetConnection to
# the Argo CD capability IAM role. Active only when argocd_idc_instance_arn is set.
#
# IMPORTANT: Only connections listed here are permitted in the IAM policy.
# Argo CD Application repoURLs must use the UUID from output connection_ids["<name>"].
# Using any other connection UUID will cause AccessDeniedException in Argo CD.
#
# After apply: complete the GitHub OAuth handshake in the AWS Console — new
# connections are in PENDING state until authorised.
# ─────────────────────────────────────────────────────────────────────────────
module "argocd_connections" {
  source = "../../modules/argocd-codeconnections"

  count = var.argocd_idc_instance_arn != null ? 1 : 0

  argocd_capability_role_name = module.eks.cluster_capability_role_names["argocd"]

  connections = [
    { name = "github-${var.cluster_name}", provider_type = "GitHub" }
  ]

  tags = var.tags
}
