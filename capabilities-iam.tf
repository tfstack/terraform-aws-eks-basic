################################################################################
# EKS Capabilities IAM Roles
# IAM roles required for EKS Capabilities (ACK, KRO, ArgoCD)
################################################################################

# IAM assume role policy documents for capabilities
data "aws_iam_policy_document" "capability_assume_role" {
  for_each = {
    for k, v in var.capabilities : k => v
    if try(v.role_arn, null) == null
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["capabilities.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

# IAM roles for capabilities (only created when role_arn is not provided)
resource "aws_iam_role" "capability" {
  for_each = {
    for k, v in var.capabilities : k => v
    if try(v.role_arn, null) == null
  }

  name               = "${var.name}-${each.key}-capability-role"
  assume_role_policy = data.aws_iam_policy_document.capability_assume_role[each.key].json

  tags = var.tags
}

# Attach IAM policies to capability roles (primarily for ACK)
resource "aws_iam_role_policy_attachment" "capability" {
  for_each = merge([
    for cap_key, cap_val in var.capabilities : {
      for pol_key, pol_arn in try(cap_val.iam_policy_arns, {}) : "${cap_key}_${pol_key}" => {
        role       = aws_iam_role.capability[cap_key].name
        policy_arn = pol_arn
      }
    }
  ]...)

  role       = each.value.role
  policy_arn = each.value.policy_arn
}
