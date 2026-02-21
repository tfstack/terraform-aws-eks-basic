variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-pod-identity-example"
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
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

# External DNS (Terraform-managed deployment)
variable "external_dns_domain_filter" {
  description = "Domain filter for External DNS (e.g. dev.example.com). Set to avoid syncing all zones."
  type        = string
  default     = ""
}

variable "external_dns_txt_owner_id" {
  description = "TXT record owner ID for External DNS (e.g. cluster name). Required if using --registry=txt."
  type        = string
  default     = ""
}

variable "external_dns_aws_zone_type" {
  description = "AWS zone type for External DNS: public or private."
  type        = string
  default     = "public"
}
