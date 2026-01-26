variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-capabilities"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.34"
}

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

variable "enable_ebs_csi_driver" {
  description = "Whether to enable the EBS CSI Driver addon"
  type        = bool
  default     = true
}

variable "enable_pod_identity_agent" {
  description = "Whether to enable the EKS Pod Identity Agent addon"
  type        = bool
  default     = true
}

variable "enable_ack_capability" {
  description = "Whether to enable ACK capability"
  type        = bool
  default     = true
}

variable "enable_kro_capability" {
  description = "Whether to enable KRO capability"
  type        = bool
  default     = true
}

variable "enable_argocd_capability" {
  description = "Whether to enable the ArgoCD capability. Note: ArgoCD requires a configuration parameter and AWS Identity Center setup."
  type        = bool
  default     = true
}

variable "kro_capability_role_arn" {
  description = "Optional IAM role ARN for the KRO capability. If not set, the module creates one."
  type        = string
  default     = null
}

variable "cluster_admin_arns" {
  description = "List of IAM user/role ARNs to grant cluster admin access via EKS access entries"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
