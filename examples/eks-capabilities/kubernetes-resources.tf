# =============================================================================
# Data Sources for Kubernetes Resource Generation
# =============================================================================

data "aws_caller_identity" "current" {}

locals {
  account_id        = data.aws_caller_identity.current.account_id
  oidc_provider_url = replace(module.eks.oidc_provider_url, "https://", "")
  enable_kro        = var.enable_kro_capability
  # Use provided role ARN if set, otherwise default to module-created role name
  kro_role_name = var.kro_capability_role_arn != null ? split("/", var.kro_capability_role_arn)[1] : "${var.cluster_name}-kro-capability-role"
}

# =============================================================================
# KRO RBAC Configuration
# =============================================================================

# ClusterRoleBinding to grant KRO role cluster-admin permissions
# cluster-admin includes permissions for all Kubernetes and ACK resources
resource "kubernetes_manifest" "kro_rbac" {
  count = local.enable_kro ? 1 : 0

  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "eks-capabilities-kro-cluster-admin"
    }
    subjects = [
      {
        kind     = "User"
        name     = "arn:aws:sts::${local.account_id}:assumed-role/${local.kro_role_name}/KRO"
        apiGroup = "rbac.authorization.k8s.io"
      }
    ]
    roleRef = {
      kind     = "ClusterRole"
      name     = "cluster-admin"
      apiGroup = "rbac.authorization.k8s.io"
    }
  }

  field_manager {
    force_conflicts = true
  }

  depends_on = [
    module.eks
  ]
}

# Allow EKS capabilities controller to list PodIdentityAssociations
resource "kubernetes_manifest" "capabilities_pod_identity_rbac" {
  count = local.enable_kro ? 1 : 0

  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRole"
    metadata = {
      name = "eks-capabilities-ack-resources-reader"
    }
    rules = [
      {
        apiGroups = ["eks.services.k8s.aws"]
        resources = ["podidentityassociations"]
        verbs     = ["get", "list", "watch"]
      },
      {
        apiGroups = ["dynamodb.services.k8s.aws"]
        resources = ["tables"]
        verbs     = ["get", "list", "watch"]
      },
      {
        apiGroups = ["s3.services.k8s.aws"]
        resources = ["buckets"]
        verbs     = ["get", "list", "watch"]
      },
      {
        apiGroups = ["iam.services.k8s.aws"]
        resources = ["roles", "policies"]
        verbs     = ["get", "list", "watch"]
      }
    ]
  }

  field_manager {
    force_conflicts = true
  }

  depends_on = [
    module.eks
  ]
}

resource "kubernetes_manifest" "capabilities_pod_identity_rbac_binding" {
  count = local.enable_kro ? 1 : 0

  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "eks-capabilities-ack-resources-reader"
    }
    subjects = [
      {
        kind     = "User"
        name     = "capabilities.eks.amazonaws.com"
        apiGroup = "rbac.authorization.k8s.io"
      }
    ]
    roleRef = {
      kind     = "ClusterRole"
      name     = "eks-capabilities-ack-resources-reader"
      apiGroup = "rbac.authorization.k8s.io"
    }
  }

  field_manager {
    force_conflicts = true
  }

  depends_on = [
    module.eks,
    kubernetes_manifest.capabilities_pod_identity_rbac
  ]
}

# =============================================================================
# KRO Resource Graph Definition (RGD)
# =============================================================================

# Generate RGD content with proper values (no file output needed)
locals {
  kro_rgd_content = local.enable_kro ? replace(
    replace(
      replace(
        file("${path.module}/kubernetes/platform-team/eks-capabilities-appstack-rgd.yaml.tpl"),
        "__ACCOUNT_ID__",
        local.account_id
      ),
      "__OIDC_PROVIDER_URL__",
      local.oidc_provider_url
    ),
    "__CLUSTER_NAME__",
    var.cluster_name
  ) : null

  kro_rgd_content_with_region = local.enable_kro ? replace(
    local.kro_rgd_content,
    "__AWS_REGION__",
    var.aws_region
  ) : null
}

# Apply the RGD to Kubernetes
resource "kubernetes_manifest" "kro_rgd" {
  count = local.enable_kro ? 1 : 0

  manifest = yamldecode(local.kro_rgd_content_with_region)

  field_manager {
    force_conflicts = true
  }

  depends_on = [
    module.eks,
    kubernetes_manifest.kro_rbac
  ]
}

# =============================================================================
# ACK Resources - DynamoDB Table and S3 Bucket (examples)
# =============================================================================

# DynamoDB Table via ACK
resource "kubernetes_manifest" "ack_dynamodb_table" {
  count = var.enable_ack_capability ? 1 : 0

  manifest = yamldecode(file("${path.module}/kubernetes/ack-resources/dynamodb-table.yaml"))

  field_manager {
    force_conflicts = true
  }

  depends_on = [
    module.eks
  ]
}

# S3 Bucket via ACK (with dynamic region)
resource "kubernetes_manifest" "ack_s3_bucket" {
  count = var.enable_ack_capability ? 1 : 0

  manifest = yamldecode(
    replace(
      file("${path.module}/kubernetes/ack-resources/s3-bucket.yaml"),
      "locationConstraint: ap-southeast-2",
      "locationConstraint: ${var.aws_region}"
    )
  )

  field_manager {
    force_conflicts = true
  }

  depends_on = [
    module.eks
  ]
}
