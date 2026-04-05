variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-automode"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster (Auto Mode requires 1.29+)"
  type        = string
  default     = "1.35"
}

# ── API Endpoint Access ──────────────────────────────────────────────────────

variable "endpoint_public_access" {
  description = "Whether the EKS API server endpoint is publicly accessible"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint. Defaults to unrestricted; tighten for production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "private_access_cidrs" {
  description = "CIDR blocks allowed to reach the private EKS API endpoint (within the VPC). Only relevant when endpoint_public_access = false or both modes are active."
  type        = list(string)
  default     = []
}

# ── Argo CD ──────────────────────────────────────────────────────────────────

variable "argocd_idc_instance_arn" {
  description = "ARN of the AWS IAM Identity Center instance for Argo CD capability. When null, the Argo CD capability and CodeConnections submodule are not created."
  type        = string
  default     = null
}

variable "argocd_rbac_role_mappings" {
  description = "Argo CD RBAC role mappings: IdC users/groups to Argo CD roles (ADMIN, EDITOR, VIEWER). Fixes 'No users or groups assigned' and Unauthorized when loading applications."
  type = list(object({
    role = string # ADMIN | EDITOR | VIEWER
    identity = list(object({
      type = string # SSO_USER or SSO_GROUP
      id   = string # IAM Identity Center user or group ID
    }))
  }))
  default = []
}

variable "argocd_vpce_ids" {
  description = "VPC interface endpoint ID(s) for the Argo CD UI (com.amazonaws.<region>.eks-capabilities). Leave empty for a public UI. See KNOWN BUG in main.tf regarding in-place switching."
  type        = list(string)
  default     = []
}

# ── Access ───────────────────────────────────────────────────────────────────

variable "access_entries" {
  description = "Map of IAM principals to grant cluster access to"
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

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
