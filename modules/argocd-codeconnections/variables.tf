variable "argocd_capability_role_name" {
  description = "IAM role name of the Argo CD EKS capability (e.g. module.eks.cluster_capability_role_names[\"argocd\"])."
  type        = string
}

variable "attach_codeconnections_policy" {
  description = "Whether to attach the CodeConnections UseConnection/GetConnection policy to the Argo CD role. Set from a value known at plan time so count is deterministic (e.g. true when using the Argo CD capability)."
  type        = bool
  default     = true
}

variable "connections" {
  description = "List of CodeStar Connections to create. Each connection is created PENDING; complete authentication in the AWS Console (e.g. GitHub OAuth) before use. Optional `key` sets Terraform/for_each and output map keys; `name` is the AWS connection name only."
  type = list(object({
    key           = optional(string) # Map key for outputs; default is name
    name          = string           # AWS CodeStar connection name (unrelated to provider_type)
    provider_type = string           # GitHub, Bitbucket, or GitHubEnterpriseServer
    host_arn      = optional(string) # For GitHub Enterprise Server or GitLab Self-Managed
  }))
}

variable "iam_role_policy_name" {
  description = "Name of the inline IAM policy on the Argo CD capability role granting codeconnections:UseConnection and GetConnection."
  type        = string
  default     = "argocd-codeconnections-use"
}

variable "tags" {
  description = "Tags to apply to created resources"
  type        = map(string)
  default     = {}
}
