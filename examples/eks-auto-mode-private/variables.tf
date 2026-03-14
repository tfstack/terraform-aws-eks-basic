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

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster (Auto Mode requires 1.29+)"
  type        = string
  default     = "1.35"
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

variable "argocd_vpce_ids" {
  description = "VPC endpoint ID(s) for EKS Capabilities (Argo CD) so the Argo CD UI is reachable only via these endpoints. Use your existing interface endpoint ID(s) for com.amazonaws.<region>.eks-capabilities."
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "ID of the existing VPC where the EKS cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS control plane (e.g. private subnets of your existing VPC)"
  type        = list(string)
}

variable "private_access_cidrs" {
  description = "List of CIDR blocks that can access the EKS private API endpoint (e.g. VPC CIDR, VPN/on-prem CIDRs)"
  type        = list(string)
  default     = []
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
