variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-minimal"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster (Auto Mode requires 1.29+)"
  type        = string
  default     = "1.35"
}

variable "vpc_id" {
  description = "ID of an existing VPC to deploy the cluster into"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs (private recommended) for EKS nodes"
  type        = list(string)
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
