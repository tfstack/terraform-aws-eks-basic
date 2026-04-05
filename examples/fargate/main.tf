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

# Pure Fargate EKS cluster — no EC2 nodes. All pods run on AWS Fargate.
#
# Credential delivery for Fargate pods:
#   Use IRSA (IAM Roles for Service Accounts): annotate the service account with
#   an IAM role ARN and the pod exchanges its OIDC token with STS directly.
#
#   EKS Pod Identity is NOT supported on Fargate. The Pod Identity agent is a
#   hostNetwork DaemonSet that only runs on EC2 nodes.
#   See: https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html
#
# EBS CSI Driver is NOT applicable on Fargate. Fargate pods cannot use EBS volumes
# (EBS is EC2-specific). Use EFS or S3 for persistent storage on Fargate.
#
# CoreDNS: configured with computeType=fargate so EKS schedules it on Fargate.
# The kube-system Fargate profile below is required for this.
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
  # ────────────────────────────────────────────────────────────────────────────
  endpoint_public_access = var.endpoint_public_access
  public_access_cidrs    = var.public_access_cidrs
  private_access_cidrs   = var.private_access_cidrs

  access_entries = var.access_entries

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
      addon_version  = "v1.21.1-eksbuild.7"
    }
  }

  fargate_profiles = {
    # Required so CoreDNS (and other kube-system pods) can schedule on Fargate.
    kube-system = {
      selectors  = [{ namespace = "kube-system" }]
      subnet_ids = module.vpc.private_subnet_ids
    }
    # Gatekeeper (Argo / Helm) installs into gatekeeper-system — needs its own profile on Fargate-only clusters.
    gatekeeper-system = {
      selectors  = [{ namespace = "gatekeeper-system" }]
      subnet_ids = module.vpc.private_subnet_ids
    }
    # Application namespace — add more selectors or profiles as needed.
    default = {
      selectors  = [{ namespace = var.fargate_namespace }]
      subnet_ids = module.vpc.private_subnet_ids
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

  # ── Secrets Manager (IRSA) ───────────────────────────────────────────────────
  # On Fargate, use IRSA — Pod Identity is NOT supported.
  # Uncomment and configure to grant service accounts Secrets Manager access.
  #
  # enable_secrets_manager        = true
  # secrets_manager_identity_type = "irsa"
  # secrets_manager_associations = [
  #   { namespace = "sm-operator-system", service_account = "awssm-sync" },
  # ]
  # secrets_manager_secret_name_prefixes = ["bitwarden/sm-operator"]
  # ────────────────────────────────────────────────────────────────────────────

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
