# eks-workload-iam

Generic submodule that creates one IAM role per Kubernetes service account, wires trust (IRSA or EKS Pod Identity), and attaches caller-supplied permissions.

**One module instance = one IAM role + one SA binding.**

The submodule is AWS-service-agnostic. The caller is responsible for building the `policy_json` (or supplying `managed_policy_arns`) for the specific AWS service the workload accesses.

## When to use

| Scenario | `identity_type` |
| --- | --- |
| EKS Auto Mode | `"pod_identity"` |
| EC2 managed node groups (with `eks-pod-identity-agent` addon) | `"pod_identity"` |
| Fargate | `"irsa"` — Pod Identity agent cannot run on Fargate |

## Usage: Pod Identity (Auto Mode / EC2 nodes)

```hcl
data "aws_iam_policy_document" "my_app_sm" {
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-app/*"
    ]
  }
}

module "my_app_workload_iam" {
  source = "../../modules/eks-workload-iam"

  identity_type   = "pod_identity"
  cluster_name    = module.eks.cluster_name
  namespace       = "my-app"
  service_account = "my-app-secrets-sync"
  role_name       = "${var.cluster_name}-my-app-sm-role"
  policy_json     = data.aws_iam_policy_document.my_app_sm.json
  tags            = var.tags
}
```

## Usage: inline `policy_json` (without `aws_iam_policy_document`)

Pass a valid IAM policy document as JSON using `jsonencode`. Useful for small, static policies when you do not need `aws_iam_policy_document` data sources.

```hcl
module "my_app_workload_iam" {
  source = "../../modules/eks-workload-iam"

  identity_type   = "pod_identity"
  cluster_name    = module.eks.cluster_name
  namespace       = "my-app"
  service_account = "my-app-secrets-sync"
  role_name       = "${var.cluster_name}-my-app-sm-role"

  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = [
          "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-app/*",
        ]
      },
    ]
  })

  tags = var.tags
}
```

## Usage: IRSA (Fargate)

```hcl
data "aws_iam_policy_document" "my_app_sm" {
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-app/*"
    ]
  }
}

module "my_app_workload_iam" {
  source = "../../modules/eks-workload-iam"

  identity_type     = "irsa"
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
  namespace         = "my-app"
  service_account   = "my-app-secrets-sync"
  role_name         = "${var.cluster_name}-my-app-sm-role"
  policy_json       = data.aws_iam_policy_document.my_app_sm.json
  tags              = var.tags
}
```

## Usage: managed policy ARN

```hcl
module "my_app_workload_iam" {
  source = "../../modules/eks-workload-iam"

  identity_type   = "pod_identity"
  cluster_name    = module.eks.cluster_name
  namespace       = "my-app"
  service_account = "my-app"
  role_name       = "${var.cluster_name}-my-app-role"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
  ]

  tags = var.tags
}
```

## Inputs

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `cluster_name` | `string` | yes | EKS cluster name |
| `identity_type` | `string` | yes | `"irsa"` or `"pod_identity"` |
| `namespace` | `string` | yes | Kubernetes namespace (not `default` or `kube-system`) |
| `service_account` | `string` | yes | Kubernetes service account name |
| `role_name` | `string` | yes | Full IAM role name (caller composes) |
| `oidc_provider_arn` | `string` | IRSA only | OIDC provider ARN (`module.eks.oidc_provider_arn`) |
| `oidc_issuer_url` | `string` | IRSA only | OIDC issuer URL (`module.eks.cluster_oidc_issuer_url`) |
| `policy_json` | `string` | at least one | Inline IAM policy JSON |
| `managed_policy_arns` | `list(string)` | at least one | Managed policy ARNs to attach |
| `tags` | `map(string)` | no | Resource tags |

## Outputs

| Name | Description |
| --- | --- |
| `role_arn` | ARN of the created IAM role |
| `role_name` | Name of the created IAM role |
| `pod_identity_association_id` | EKS Pod Identity association ID, or `null` for IRSA |
