# =============================================================================
# EKS AutoMode Configuration
# =============================================================================

# Note: AutoMode is configured via the compute block in the EKS cluster resource
# This file is reserved for future AutoMode-specific resources and configurations
# when they become available in the AWS provider

# AutoMode configuration is handled in main.tf within the aws_eks_cluster resource
# using the dynamic "compute" block. This structure allows for future expansion
# of AutoMode features as they become available.

locals {
  # Helper to determine if AutoMode is enabled
  automode_enabled = contains(var.compute_mode, "automode")
}
