output "codeconnections_iam_role_name" {
  description = "IAM role name that receives the CodeConnections inline policy (Argo CD capability role)."
  value       = var.argocd_capability_role_name
}

output "codeconnections_iam_policy_name" {
  description = "Name of the inline IAM policy on the Argo CD capability role (UseConnection + GetConnection)."
  value       = var.iam_role_policy_name
}

output "connection_arns" {
  description = "ARNs of the created CodeStar Connections. Use in Argo CD Application repoURL or pass to root module capabilities.argocd.code_connection_arns if not using this submodule's IAM attachment."
  value       = [for c in aws_codestarconnections_connection.this : c.arn]
}

# Connection ID (UUID only). AWS provider's c.id is the full ARN; repo URL path requires the UUID.
locals {
  connection_id_uuid = { for k, c in aws_codestarconnections_connection.this : k => element(split("/", c.id), 1) }
}

output "connection_ids" {
  description = "Map of connection key (connections[].key if set, else name) to connection ID (UUID only, for building repo URL). Do not use the full ARN in the URL path."
  value       = local.connection_id_uuid
}

output "repository_url_template" {
  description = "CodeConnections Git HTTP URL template for Argo CD Application source.repoURL. Replace OWNER and REPO (and optional connection name if multiple)."
  value       = "https://codeconnections.${data.aws_region.current.id}.amazonaws.com/git-http/${data.aws_caller_identity.current.account_id}/${data.aws_region.current.id}/CONNECTION_ID/OWNER/REPO.git"
}

output "repository_url_templates" {
  description = "Map of connection key (connections[].key if set, else name) to repo URL template using that connection's UUID."
  value = {
    for k, c in aws_codestarconnections_connection.this : k =>
    "https://codeconnections.${data.aws_region.current.id}.amazonaws.com/git-http/${data.aws_caller_identity.current.account_id}/${data.aws_region.current.id}/${local.connection_id_uuid[k]}/OWNER/REPO.git"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
