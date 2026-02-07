################################################################################
# Core Cluster Configuration
################################################################################

variable "name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}

################################################################################
# Network Configuration
################################################################################

variable "vpc_id" {
  description = "VPC ID where the cluster is deployed"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EKS cluster control plane (should include both public and private)"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Whether the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_ip_family" {
  description = "IP family for the EKS cluster. Valid values: ipv4, ipv6"
  type        = string
  default     = "ipv4"

  validation {
    condition     = contains(["ipv4", "ipv6"], var.cluster_ip_family)
    error_message = "cluster_ip_family must be either 'ipv4' or 'ipv6'"
  }
}

variable "service_ipv4_cidr" {
  description = "IPv4 CIDR block for Kubernetes services. Required for all clusters. Must not overlap with VPC CIDR. If not provided, EKS will auto-assign."
  type        = string
  default     = null
}

################################################################################
# Logging Configuration
################################################################################

variable "enabled_cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "create_cloudwatch_log_group" {
  description = "Whether to create a CloudWatch log group for EKS cluster logs"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "Number of days to retain log events in the CloudWatch log group"
  type        = number
  default     = 14
}

variable "cloudwatch_log_group_kms_key_id" {
  description = "The ARN of the KMS Key to use when encrypting log data"
  type        = string
  default     = null
}

variable "cloudwatch_log_group_class" {
  description = "Specifies the log class of the log group. Valid values are: STANDARD or INFREQUENT_ACCESS"
  type        = string
  default     = null
}

variable "cloudwatch_log_group_tags" {
  description = "Additional tags to apply to the CloudWatch log group"
  type        = map(string)
  default     = {}
}

variable "region" {
  description = "AWS region for CloudWatch log group"
  type        = string
  default     = "ap-southeast-2"
}

################################################################################
# Access & Authentication Configuration
################################################################################

variable "cluster_authentication_mode" {
  description = "Authentication mode for the EKS cluster. Valid values: CONFIG_MAP, API, API_AND_CONFIG_MAP. Defaults to API_AND_CONFIG_MAP when capabilities are enabled, otherwise CONFIG_MAP."
  type        = string
  default     = "API_AND_CONFIG_MAP"

  validation {
    condition     = contains(["CONFIG_MAP", "API", "API_AND_CONFIG_MAP"], var.cluster_authentication_mode)
    error_message = "cluster_authentication_mode must be one of: CONFIG_MAP, API, API_AND_CONFIG_MAP"
  }
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Indicates whether or not to add the cluster creator (the identity used by Terraform) as an administrator via access entry"
  type        = bool
  default     = false
}

variable "access_entries" {
  description = "Map of access entries to add to the cluster"
  type = map(object({
    # Access entry
    kubernetes_groups = optional(list(string))
    principal_arn     = string
    type              = optional(string, "STANDARD")
    user_name         = optional(string)
    tags              = optional(map(string), {})
    # Access policy association
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

################################################################################
# Encryption Configuration
################################################################################

variable "create_kms_key" {
  description = "Controls if a KMS key for cluster encryption should be created"
  type        = bool
  default     = true
}

variable "cluster_encryption_config_key_arn" {
  description = "ARN of the KMS key to use for encrypting Kubernetes secrets"
  type        = string
  default     = null
}

variable "cluster_encryption_config_resources" {
  description = "List of strings with resources to be encrypted. Valid values: secrets"
  type        = list(string)
  default     = ["secrets"]
}

################################################################################
# Addons Configuration
################################################################################

variable "addons" {
  description = "Map of EKS addons to enable"
  type = map(object({
    addon_version               = optional(string)
    before_compute              = optional(bool, false)
    configuration_values        = optional(string)
    resolve_conflicts_on_create = optional(string, "OVERWRITE")
    resolve_conflicts_on_update = optional(string, "OVERWRITE")
    service_account_role_arn    = optional(string)
  }))
  default = {}
}

variable "enable_aws_load_balancer_controller" {
  description = "Whether to create IAM role for AWS Load Balancer Controller (IRSA)"
  type        = bool
  default     = false
}

################################################################################
# Capabilities Configuration
################################################################################

variable "capabilities" {
  description = "Map of EKS capabilities to enable. Valid keys: ack, kro, argocd"
  type = map(object({
    role_arn                  = optional(string)
    iam_policy_arns           = optional(map(string), {})
    configuration             = optional(string)
    delete_propagation_policy = optional(string, "RETAIN")
  }))
  default = {}
}

################################################################################
# Node Group Configuration
################################################################################

variable "eks_managed_node_groups" {
  description = "Map of EKS managed node group configurations"
  type = map(object({
    name                       = optional(string)
    ami_type                   = optional(string, "AL2023_x86_64_STANDARD")
    instance_types             = optional(list(string), ["t3.medium"])
    min_size                   = optional(number, 1)
    max_size                   = optional(number, 3)
    desired_size               = optional(number, 2)
    disk_size                  = optional(number, 20)
    subnet_ids                 = optional(list(string))
    enable_bootstrap_user_data = optional(bool, true)
    metadata_options = optional(object({
      http_endpoint               = optional(string, "enabled")
      http_tokens                 = optional(string, "required")
      http_put_response_hop_limit = optional(number, 1)
    }))
    labels = optional(map(string), {})
    tags   = optional(map(string), {})
  }))
  default = {}
}
