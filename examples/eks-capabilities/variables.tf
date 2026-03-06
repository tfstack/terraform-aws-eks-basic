variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "cltest"
}

variable "argocd_idc_instance_arn" {
  description = "ARN of the AWS IAM Identity Center instance for Argo CD capability. When null, the Argo CD capability is not created (only ACK and KRO are created)."
  type        = string
}

variable "argocd_rbac_role_mappings" {
  description = "Argo CD RBAC role mappings: IdC users/groups (from the same IdC instance) to Argo CD roles (ADMIN, EDITOR, or VIEWER). Fixes 'No users or groups assigned' and Unauthorized when loading applications."
  type = list(object({
    role = string # ADMIN | EDITOR | VIEWER
    identity = list(object({
      type = string # SSO_USER or SSO_GROUP
      id   = string # IAM Identity Center user or group ID
    }))
  }))
  default = []
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.35"
}

variable "access_entries" {
  description = "Map of access entries to add to the cluster"
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
