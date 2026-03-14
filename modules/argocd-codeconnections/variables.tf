variable "argocd_capability_role_arn" {
  description = "IAM role ARN of the Argo CD EKS Capability (e.g. module.eks.cluster_capability_role_arns[\"argocd\"]). UseConnection and GetConnection policies will be attached to this role."
  type        = string
}

variable "connections" {
  description = "List of CodeStar Connections to create. Each connection is created PENDING; complete authentication in the AWS Console (e.g. GitHub OAuth) before use."
  type = list(object({
    name          = string
    provider_type = string           # GitHub, Bitbucket, or GitHubEnterpriseServer
    host_arn      = optional(string) # For GitHub Enterprise Server or GitLab Self-Managed
  }))
}

variable "tags" {
  description = "Tags to apply to created resources"
  type        = map(string)
  default     = {}
}
