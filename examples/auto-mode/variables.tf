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

# ── Headlamp ──────────────────────────────────────────────────────────────────

variable "headlamp_hostnames" {
  description = "Hostnames where headlamp is exposed via ALB ingress (one per cluster overlay that has ingress enabled). Used to populate Cognito app client callback/logout URLs. Port-forward users do not need to add entries here — localhost:4466 is always included."
  type        = list(string)
  default     = []
}

variable "headlamp_saml_metadata_url" {
  description = <<-EOT
    SAML federation metadata URL for Cognito (phase 2). Use the public metadata URL from your IdP, for example:
    Microsoft Entra ID: Enterprise application → SAML single sign-on → "App Federation Metadata Url", or the
    federation metadata URL shown for that app. AWS IAM Identity Center: custom SAML app → IAM Identity Center metadata URL.
    Leave null on first apply; use outputs headlamp_cognito_saml_acs_url and headlamp_cognito_saml_entity_id to configure the IdP.
    If both this and headlamp_idc_saml_metadata_url are set, this variable wins.
  EOT
  type        = string
  default     = null
}

variable "headlamp_idc_saml_metadata_url" {
  description = <<-EOT
    Deprecated: use headlamp_saml_metadata_url. Kept for backward compatibility with existing tfvars.
  EOT
  type        = string
  default     = null
}

variable "headlamp_saml_provider_name" {
  description = <<-EOT
    Cognito SAML identity provider name (must match supported_identity_providers on the app client).
    Use "AzureAD" for Microsoft Entra ID enterprise SAML apps, or "IdentityCenter" for IAM Identity Center.
  EOT
  type        = string
  default     = "IdentityCenter"

  validation {
    condition     = length(var.headlamp_saml_provider_name) >= 1 && length(var.headlamp_saml_provider_name) <= 32
    error_message = "headlamp_saml_provider_name must be 1-32 characters (Cognito SAML provider name limit)."
  }
}

variable "headlamp_rbac_group_rules" {
  description = <<-EOT
    Ordered rules for the Headlamp Pre Token Lambda: each entry maps a SAML directory group string (Entra display
    name or object ID) to a Kubernetes group name on cognito:groups. List order is the walk order (higher privilege
    rules first is conventional). directory_group must match the SAML claim byte-for-byte. k8s_group must match
    ClusterRoleBinding subjects[].name in apps/headlamp/base/rbac.yaml. Users with no matching rule are denied.
  EOT
  type = list(object({
    directory_group = string
    k8s_group       = string
  }))
  default = [
    { directory_group = "SSO-ArgoCD Admin", k8s_group = "platform-admins" },
    { directory_group = "SSO-ArgoCD ReadOnly", k8s_group = "platform-readonly" },
  ]
}
