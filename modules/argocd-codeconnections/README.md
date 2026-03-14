# Argo CD CodeConnections

Creates AWS CodeStar Connections for Argo CD (EKS Capabilities) and attaches `codeconnections:UseConnection` and `codeconnections:GetConnection` to the Argo CD capability role so Applications can use the [CodeConnections repo URL](https://docs.aws.amazon.com/eks/latest/userguide/argocd-configure-repositories.html) without storing credentials.

## Usage (Option B)

Call this submodule after creating the EKS cluster with the Argo CD capability. The submodule creates the connection(s) and attaches the IAM policy to the role.

```hcl
module "argocd_connections" {
  source = "../../modules/argocd-codeconnections"

  argocd_capability_role_arn = module.eks.cluster_capability_role_arns["argocd"]

  connections = [
    { name = "github", provider_type = "GitHub" }
  ]

  tags = var.tags
}
```

After apply, **complete the connection in the AWS Console** (e.g. GitHub OAuth). Connections are created in `PENDING` state until authentication is done.

## Application repoURL

Use the output `repository_url_templates` to build the `source.repoURL` in an Argo CD Application. For a single connection named `github`:

```yaml
spec:
  source:
    repoURL: https://codeconnections.REGION.amazonaws.com/git-http/ACCOUNT/REGION/CONNECTION_ID/owner/repo.git
    targetRevision: main
```

Replace `CONNECTION_ID` with `module.argocd_connections.connection_ids["github"]`, and `owner`/`repo` with your Git org and repository name.

## Inputs

| Name | Description |
| --- | --- |
| argocd_capability_role_arn | IAM role ARN of the Argo CD capability (e.g. from `cluster_capability_role_arns["argocd"]`). |
| connections | List of `{ name, provider_type }`. `provider_type`: `GitHub`, `Bitbucket`, or `GitHubEnterpriseServer`. Optional `host_arn` for GitHub Enterprise / GitLab. |
| tags | Tags for created resources. |

## Outputs

| Name | Description |
| --- | --- |
| connection_arns | ARNs of created connections. |
| connection_ids | Map of connection name to connection ID (for repo URL). |
| repository_url_template | Generic URL template. |
| repository_url_templates | Map of connection name to URL template with that connection's ID. |

## Alternative (Option A)

To attach CodeConnections permission without this submodule (e.g. connections created elsewhere), pass the connection ARNs in the root module:

```hcl
capabilities = {
  argocd = {
    configuration = { ... }
    code_connection_arns = ["arn:aws:codestar-connections:REGION:ACCOUNT:connection/CONNECTION_ID"]
  }
}
```
