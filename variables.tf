variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
}

variable "compute_mode" {
  description = "List of compute modes to enable. Valid values: ec2, fargate, automode"
  type        = list(string)
  default     = ["ec2"]

  validation {
    condition = alltrue([
      for mode in var.compute_mode : contains(["ec2", "fargate", "automode"], mode)
    ])
    error_message = "compute_mode must contain only 'ec2', 'fargate', or 'automode'"
  }
}

variable "vpc_id" {
  description = "VPC ID where the cluster is deployed"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EKS cluster control plane (should include both public and private)"
  type        = list(string)
}

variable "node_subnet_ids" {
  description = "Subnet IDs for EKS node groups (should be private subnets only for security). If null, uses subnet_ids."
  type        = list(string)
  default     = null
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

variable "enabled_cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_authentication_mode" {
  description = "Authentication mode for the EKS cluster. Valid values: CONFIG_MAP, API, API_AND_CONFIG_MAP. Defaults to API_AND_CONFIG_MAP when capabilities are enabled, otherwise CONFIG_MAP."
  type        = string
  default     = "CONFIG_MAP"

  validation {
    condition     = contains(["CONFIG_MAP", "API", "API_AND_CONFIG_MAP"], var.cluster_authentication_mode)
    error_message = "cluster_authentication_mode must be one of: CONFIG_MAP, API, API_AND_CONFIG_MAP"
  }
}

# =============================================================================
# EC2 Node Group Variables
# =============================================================================

variable "node_instance_types" {
  description = "List of EC2 instance types for the node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 3
}

variable "node_disk_size" {
  description = "Disk size in GiB for worker nodes"
  type        = number
  default     = 20
}

variable "node_update_max_unavailable" {
  description = "Maximum number of nodes unavailable during update"
  type        = number
  default     = 1
}

variable "node_remote_access_enabled" {
  description = "Whether to enable remote access to nodes"
  type        = bool
  default     = false
}

variable "node_remote_access_ssh_key" {
  description = "EC2 SSH key name for remote access"
  type        = string
  default     = null
}

variable "node_remote_access_security_groups" {
  description = "List of security group IDs for remote access"
  type        = list(string)
  default     = []
}

variable "node_labels" {
  description = "Key-value map of Kubernetes labels to apply to nodes"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Fargate Variables
# =============================================================================

variable "fargate_profiles" {
  description = "Map of Fargate profiles to create. Key is the profile name."
  type = map(object({
    subnet_ids = optional(list(string))
    selectors = optional(list(object({
      namespace = string
      labels    = optional(map(string))
    })), [])
    tags = optional(map(string))
  }))
  default = {}
}

# =============================================================================
# AutoMode Variables
# =============================================================================

# AutoMode variables will be added here as the feature becomes available
# Currently, AutoMode is configured via the compute block in the cluster resource

# =============================================================================
# AWS Auth Variables
# =============================================================================

variable "aws_auth_map_users" {
  description = "List of IAM users to add to aws-auth ConfigMap for Kubernetes access"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "aws_auth_map_roles" {
  description = "List of IAM roles to add to aws-auth ConfigMap for Kubernetes access"
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

# =============================================================================
# Addon Variables
# =============================================================================

variable "enable_ebs_csi_driver" {
  description = "Whether to install AWS EBS CSI Driver"
  type        = bool
  default     = false
}

variable "enable_pod_identity_agent" {
  description = "Whether to install EKS Pod Identity Agent add-on"
  type        = bool
  default     = false
}

variable "pod_identity_agent_version" {
  description = "Version of the EKS Pod Identity Agent add-on. If null, uses latest version."
  type        = string
  default     = null
}

variable "ebs_csi_driver_version" {
  description = "Version of the AWS EBS CSI Driver add-on. If null, uses latest version."
  type        = string
  default     = null
}

variable "enable_aws_lb_controller" {
  description = "Whether to install AWS Load Balancer Controller"
  type        = bool
  default     = false
}

variable "aws_lb_controller_helm_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart"
  type        = string
  default     = "1.7.2"
}

variable "aws_lb_controller_helm_values" {
  description = "Additional Helm values for the AWS Load Balancer Controller"
  type        = map(string)
  default     = {}
}

# =============================================================================
# EKS Capabilities Variables
# =============================================================================

variable "enable_ack_capability" {
  description = "Whether to enable AWS Controllers for Kubernetes (ACK) capability"
  type        = bool
  default     = false
}

variable "enable_kro_capability" {
  description = "Whether to enable Kube Resource Orchestrator (KRO) capability"
  type        = bool
  default     = false
}

variable "enable_argocd_capability" {
  description = "Whether to enable ArgoCD GitOps capability. NOTE: Not currently supported - requires AWS Identity Center configuration. Scaffolded for future use."
  type        = bool
  default     = false
}

variable "ack_capability_role_arn" {
  description = "IAM role ARN for ACK capability to create AWS resources. If not provided, AWS will create a default role."
  type        = string
  default     = null
}

variable "ack_capability_iam_policy_arns" {
  description = "Map of IAM policy ARNs to attach to the ACK capability role. Required for ACK to manage AWS resources (e.g., S3, DynamoDB, IAM)."
  type        = map(string)
  default     = {}
}

variable "kro_capability_role_arn" {
  description = "IAM role ARN for KRO capability. If not provided, AWS will create a default role."
  type        = string
  default     = null
}

variable "argocd_capability_role_arn" {
  description = "IAM role ARN for ArgoCD capability. NOTE: ArgoCD not currently supported - requires AWS Identity Center. Scaffolded for future use."
  type        = string
  default     = null
}

variable "argocd_capability_configuration" {
  description = "Configuration JSON for ArgoCD capability. NOTE: ArgoCD not currently supported - requires AWS Identity Center configuration. Scaffolded for future use."
  type        = string
  default     = null
}

# =============================================================================
# Common Variables
# =============================================================================

variable "cluster_admin_arns" {
  description = "List of IAM user/role ARNs to grant cluster admin access via EKS access entries. Only used when capabilities are enabled or cluster_authentication_mode is not CONFIG_MAP. Defaults to empty list."
  type        = list(string)
  default     = []
}

variable "access_entry_wait_duration" {
  description = "Duration to wait after creating EKS access entries before creating node groups/Fargate profiles. This allows AWS to propagate the access entries. Defaults to 30s."
  type        = string
  default     = "30s"
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}
