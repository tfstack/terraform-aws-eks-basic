variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "vpc_name" {
  description = "Name tag for the shared VPC (also drives subnet kubernetes.io/cluster tag for the classic cluster via the VPC module)"
  type        = string
  default     = "eks-shared"
}

variable "tags" {
  description = "Common tags for VPC and all three clusters"
  type        = map(string)
  default = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# ── Cluster identity ─────────────────────────────────────────────────────────

variable "cluster_names" {
  description = "Unique EKS cluster names (must be distinct). Classic name should match what the VPC module uses for kubernetes.io/cluster/* subnet tags."
  type = object({
    classic  = string
    fargate  = string
    automode = string
  })
  default = {
    classic  = "eks-shared-classic"
    fargate  = "eks-shared-fargate"
    automode = "eks-shared-automode"
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for all three clusters (Auto Mode requires 1.29+)"
  type        = string
  default     = "1.35"
}

# ── API access (shared defaults for all three clusters) ─────────────────────

variable "endpoint_public_access" {
  description = "Whether each cluster's Kubernetes API is publicly reachable"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "private_access_cidrs" {
  type    = list(string)
  default = []
}

# ── EKS access entries (one map per cluster) ────────────────────────────────

variable "access_entries_classic" {
  description = "Access entries for the classic (EC2) cluster"
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

variable "access_entries_fargate" {
  description = "Access entries for the Fargate cluster"
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

variable "access_entries_automode" {
  description = "Access entries for the Auto Mode cluster"
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

# ── Argo CD (same IdC config applied to all three clusters; separate installs + CodeConnections each) ──

variable "argocd_idc_instance_arn" {
  description = "IAM Identity Center instance ARN. When null, Argo CD and CodeConnections are disabled on all three clusters."
  type        = string
  default     = null
}

variable "argocd_rbac_role_mappings" {
  description = "Shared RBAC mappings for all three Argo CD UIs"
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
  description = "Shared VPC interface endpoint IDs for Argo CD UI on all three clusters (empty = public UI)"
  type        = list(string)
  default     = []
}

# ── Fargate-only ───────────────────────────────────────────────────────────

variable "fargate_namespace" {
  description = "Namespace matched by the default Fargate profile on the Fargate cluster"
  type        = string
  default     = "app"
}
