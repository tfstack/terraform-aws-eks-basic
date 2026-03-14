################################################################################
# Argo CD CodeConnections – create connections and attach UseConnection + GetConnection to Argo CD role
# See: https://docs.aws.amazon.com/eks/latest/userguide/integration-codeconnections.html
################################################################################

locals {
  # IAM role_policy requires role name; derive from ARN (arn:aws:iam::ACCOUNT:role/NAME)
  argocd_role_name = try(regex("role/(.+)$", var.argocd_capability_role_arn)[0], null)
}

resource "aws_codestarconnections_connection" "this" {
  for_each = { for i, c in var.connections : c.name => c }

  name          = each.value.name
  provider_type = each.value.provider_type
  host_arn      = try(each.value.host_arn, null)

  tags = var.tags
}

# Inline policy on the Argo CD capability role so Argo CD can use these connections (UseConnection + GetConnection per AWS docs).
data "aws_iam_policy_document" "codeconnections_use" {
  statement {
    effect = "Allow"
    actions = [
      "codeconnections:UseConnection",
      "codeconnections:GetConnection"
    ]
    resources = [for c in aws_codestarconnections_connection.this : c.arn]
  }
}

resource "aws_iam_role_policy" "codeconnections" {
  count = local.argocd_role_name != null ? 1 : 0

  name   = "argocd-codeconnections-use"
  role   = local.argocd_role_name
  policy = data.aws_iam_policy_document.codeconnections_use.json
}
