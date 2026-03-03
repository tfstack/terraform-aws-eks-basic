################################################################################
# Secrets Manager IAM Role (IRSA or EKS Pod Identity)
# IAM role for application pods to access AWS Secrets Manager via Secrets Store CSI Driver
#
# When using Pod Identity:
# - Requires eks-pod-identity-agent addon in addons
# - secrets_manager_associations lists {namespace, service_account} per workload
# - Create each namespace and ServiceAccount in Kubernetes before pods use them
# - Set usePodIdentity: "true" in SecretProviderClass parameters
# - One IAM role shared; one Pod Identity association per (namespace, service_account)
################################################################################

# IAM assume role policy document for Secrets Manager (IRSA)
# Supports multiple namespaces: each (namespace, service_account) can assume the role
data "aws_iam_policy_document" "secrets_manager_assume_role_irsa" {
  count = var.enable_secrets_manager ? 1 : 0

  dynamic "statement" {
    for_each = length(var.secrets_manager_associations) > 0 ? [1] : []
    content {
      effect = "Allow"

      principals {
        type        = "Federated"
        identifiers = [aws_iam_openid_connect_provider.oidc_provider[0].arn]
      }

      actions = ["sts:AssumeRoleWithWebIdentity"]

      condition {
        test     = "StringEquals"
        variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub"
        values   = [for a in var.secrets_manager_associations : "system:serviceaccount:${a.namespace}:${a.service_account}"]
      }

      condition {
        test     = "StringEquals"
        variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

# IAM assume role policy document for Secrets Manager (EKS Pod Identity)
data "aws_iam_policy_document" "secrets_manager_assume_role_pod_identity" {
  count = var.enable_secrets_manager ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

# IAM role for Secrets Manager (IRSA or Pod Identity per secrets_manager_identity_type)
resource "aws_iam_role" "secrets_manager" {
  count = var.enable_secrets_manager ? 1 : 0

  name               = "${var.name}-secrets-manager-role"
  assume_role_policy = var.secrets_manager_identity_type == "pod_identity" ? data.aws_iam_policy_document.secrets_manager_assume_role_pod_identity[0].json : data.aws_iam_policy_document.secrets_manager_assume_role_irsa[0].json

  tags = var.tags

  lifecycle {
    precondition {
      condition = !var.enable_secrets_manager || (
        length(var.secrets_manager_associations) > 0 &&
        !contains([for a in var.secrets_manager_associations : a.namespace], "") &&
        !contains([for a in var.secrets_manager_associations : a.namespace], "default") &&
        !contains([for a in var.secrets_manager_associations : a.namespace], "kube-system")
      )
      error_message = "secrets_manager_associations must be a non-empty list of {namespace, service_account} when enable_secrets_manager is true. Do not use 'default' or 'kube-system'."
    }
  }

  depends_on = [
    aws_iam_openid_connect_provider.oidc_provider
  ]
}

# Custom least-privilege policy when secret_name_prefixes specified
data "aws_iam_policy_document" "secrets_manager_scoped" {
  count = var.enable_secrets_manager && length(var.secrets_manager_secret_name_prefixes) > 0 ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      for prefix in var.secrets_manager_secret_name_prefixes :
      "arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:${prefix}*"
    ]
  }
}

resource "aws_iam_role_policy" "secrets_manager_scoped" {
  count = var.enable_secrets_manager && length(var.secrets_manager_secret_name_prefixes) > 0 ? 1 : 0

  name   = "secrets-manager-scoped"
  role   = aws_iam_role.secrets_manager[0].name
  policy = data.aws_iam_policy_document.secrets_manager_scoped[0].json
}

# Attach AWS managed policy when no secret_name_prefixes (broad access)
resource "aws_iam_role_policy_attachment" "secrets_manager" {
  count = var.enable_secrets_manager && length(var.secrets_manager_secret_name_prefixes) == 0 ? 1 : 0

  role       = aws_iam_role.secrets_manager[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSSecretsManagerClientReadOnlyAccess"
}

# Attach AWS managed policy for Parameter Store (optional)
resource "aws_iam_role_policy_attachment" "secrets_manager_parameter_store" {
  count = var.enable_secrets_manager && var.secrets_manager_enable_parameter_store ? 1 : 0

  role       = aws_iam_role.secrets_manager[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# EKS Pod Identity associations for Secrets Manager (one per association)
resource "aws_eks_pod_identity_association" "secrets_manager" {
  for_each = var.enable_secrets_manager && var.secrets_manager_identity_type == "pod_identity" ? {
    for i, a in var.secrets_manager_associations : "${a.namespace}/${a.service_account}" => a
  } : {}

  cluster_name    = aws_eks_cluster.this.name
  namespace       = each.value.namespace
  service_account = each.value.service_account
  role_arn        = aws_iam_role.secrets_manager[0].arn
}
