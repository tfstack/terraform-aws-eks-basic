################################################################################
# eks-workload-iam — Variables
# Generic per-SA workload IAM submodule: one IAM role, one SA binding, caller-
# supplied policy. Supports IRSA (Fargate-safe) and EKS Pod Identity.
################################################################################

variable "cluster_name" {
  description = "EKS cluster name. Used in the Pod Identity association and may be used by the caller to compose the role name."
  type        = string
}

variable "identity_type" {
  description = "Credential mechanism for the workload. 'irsa' uses OIDC Web Identity (Fargate-compatible). 'pod_identity' uses EKS Pod Identity (requires eks-pod-identity-agent addon; not supported on Fargate)."
  type        = string

  default = "irsa"
  validation {
    condition     = contains(["irsa", "pod_identity"], var.identity_type)
    error_message = "identity_type must be 'irsa' or 'pod_identity'."
  }
}

variable "namespace" {
  description = "Kubernetes namespace of the workload service account. Must not be 'default' or 'kube-system'."
  type        = string
}

variable "service_account" {
  description = "Kubernetes service account name that will assume the IAM role."
  type        = string
}

variable "role_name" {
  description = "Full IAM role name. The caller composes a unique name (e.g. my-cluster-headlamp-sm-role)."
  type        = string
}

# ── IRSA-only inputs ─────────────────────────────────────────────────────────
# Required when identity_type = "irsa"; ignored for pod_identity.
# ────────────────────────────────────────────────────────────────────────────

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC provider (module.eks.oidc_provider_arn). Required when identity_type = 'irsa'."
  type        = string
  default     = null
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster, including the https:// prefix (module.eks.cluster_oidc_issuer_url). Required when identity_type = 'irsa'. The module strips the scheme when building the IRSA trust condition."
  type        = string
  default     = null
}

# ── Permissions ──────────────────────────────────────────────────────────────
# At least one of policy_json or managed_policy_arns must be provided.
# ────────────────────────────────────────────────────────────────────────────

variable "policy_json" {
  description = "Inline IAM policy JSON to attach to the role. Use for least-privilege service-specific policies (e.g. scoped GetSecretValue). At least one of policy_json or managed_policy_arns must be set."
  type        = string
  default     = null
}

variable "managed_policy_arns" {
  description = "List of AWS managed or customer-managed policy ARNs to attach to the role. At least one of managed_policy_arns or policy_json must be set."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all created resources."
  type        = map(string)
  default     = {}
}
