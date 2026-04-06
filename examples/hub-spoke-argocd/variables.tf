variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "vpc_name" {
  description = "Name tag for the shared VPC"
  type        = string
  default     = "vpc-eks-hub-spoke"
}

variable "tags" {
  description = "Common tags for VPC and all clusters"
  type        = map(string)
  default = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# ── Cluster identity ──────────────────────────────────────────────────────────

variable "cluster_names" {
  description = "EKS cluster names. Hub name drives the VPC module's primary kubernetes.io/cluster/* subnet tag."
  type = object({
    hub        = string
    spoke_dev  = string
    spoke_prod = string
  })
  default = {
    hub        = "eks-10"
    spoke_dev  = "eks-11"
    spoke_prod = "eks-12"
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for all clusters (Auto Mode requires 1.29+)"
  type        = string
  default     = "1.35"
}

# ── API access (shared for all clusters) ─────────────────────────────────────

variable "endpoint_public_access" {
  description = "Whether each cluster's Kubernetes API is publicly reachable"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks that can reach the public API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "private_access_cidrs" {
  description = "CIDR blocks that can reach the private API endpoint"
  type        = list(string)
  default     = []
}

# ── EKS access entries (one map per cluster) ──────────────────────────────────
# Note: spoke clusters automatically receive an argocd_hub access entry for the
# hub Argo CD capability role — you do not need to add it here manually.

variable "access_entries_hub" {
  description = "Access entries for the hub cluster"
  type = map(object({
    kubernetes_groups = optional(list(string))
    principal_arn     = string
    type              = optional(string, "STANDARD")
    user_name         = optional(string)
    tags              = optional(map(string), {})
    policy_associations = optional(map(object({
      policy_arn = string
      access_scope = object({
        namespaces = optional(list(string))
        type       = string
      })
    })), {})
  }))
  default = {}
}

variable "access_entries_spoke_dev" {
  description = "Access entries for module.eks_spoke_1 (cluster name from cluster_names.spoke_dev). argocd_hub (hub Argo CD role) is added automatically."
  type = map(object({
    kubernetes_groups = optional(list(string))
    principal_arn     = string
    type              = optional(string, "STANDARD")
    user_name         = optional(string)
    tags              = optional(map(string), {})
    policy_associations = optional(map(object({
      policy_arn = string
      access_scope = object({
        namespaces = optional(list(string))
        type       = string
      })
    })), {})
  }))
  default = {}
}

variable "access_entries_spoke_prod" {
  description = "Access entries for module.eks_spoke_2 (cluster name from cluster_names.spoke_prod). argocd_hub (hub Argo CD role) is added automatically."
  type = map(object({
    kubernetes_groups = optional(list(string))
    principal_arn     = string
    type              = optional(string, "STANDARD")
    user_name         = optional(string)
    tags              = optional(map(string), {})
    policy_associations = optional(map(object({
      policy_arn = string
      access_scope = object({
        namespaces = optional(list(string))
        type       = string
      })
    })), {})
  }))
  default = {}
}

# ── Argo CD (hub cluster only) ────────────────────────────────────────────────
# argocd_idc_instance_arn is required: the hub needs AWS IAM Identity Center
# for the managed Argo CD capability, and spoke clusters are wired to the hub
# Argo CD role which only exists when argocd is in capabilities.

variable "argocd_idc_instance_arn" {
  description = "IAM Identity Center instance ARN. Required for hub Argo CD capability and spoke cluster wiring."
  type        = string
}

variable "argocd_rbac_role_mappings" {
  description = "RBAC role mappings for the hub Argo CD UI"
  type = list(object({
    role = string
    identity = list(object({
      type = string
      id   = string
    }))
  }))
  default = []
}

variable "argocd_vpce_ids" {
  description = "VPC interface endpoint IDs for the hub Argo CD UI (empty = public UI)"
  type        = list(string)
  default     = []
}
