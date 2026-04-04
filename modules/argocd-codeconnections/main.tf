################################################################################
# Argo CD CodeConnections – create connections and attach UseConnection + GetConnection to Argo CD role
# See: https://docs.aws.amazon.com/eks/latest/userguide/integration-codeconnections.html
################################################################################

locals {
  connections_map = {
    for c in var.connections :
    coalesce(try(c.key, null), c.name) => c
  }
}

resource "aws_codestarconnections_connection" "this" {
  for_each = local.connections_map

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
  count = var.attach_codeconnections_policy ? 1 : 0

  name   = var.iam_role_policy_name
  role   = var.argocd_capability_role_name
  policy = data.aws_iam_policy_document.codeconnections_use.json

  lifecycle {
    precondition {
      condition     = length(var.connections) > 0
      error_message = "Provide at least one entry in `connections` when attach_codeconnections_policy is true."
    }
  }
}
