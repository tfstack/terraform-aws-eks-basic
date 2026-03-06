# EKS Capabilities Example

This example creates an EKS cluster with one or more [EKS Capabilities](https://docs.aws.amazon.com/eks/latest/userguide/capabilities.html): **ACK** (AWS Controllers for Kubernetes), **KRO** (Kube Resource Orchestrator), and optionally **Argo CD**. Capabilities are fully managed by AWS and run in EKS rather than on your worker nodes.

You can create at most **one capability resource of each type** (Argo CD, ACK, kro) per cluster. This example enables ACK and KRO by default; Argo CD is only created when `argocd_idc_instance_arn` is set.

- **ACK** – Manage AWS resources (e.g. S3, RDS) via Kubernetes APIs. The example attaches a broad S3 policy for simplicity.
- **KRO** (kro) – Create custom Kubernetes APIs that compose resources. No extra config required at creation.
- **Argo CD** – GitOps-based continuous deployment. Requires [AWS IAM Identity Center](https://docs.aws.amazon.com/eks/latest/userguide/capabilities.html) (IdC) at creation; set `argocd_idc_instance_arn` and optionally configure `rbac_role_mapping` (ADMIN/EDITOR/VIEWER) for IdC users or groups.

## Argo CD RBAC and IAM Identity Center

Without `argocd_rbac_role_mappings`, the console shows "No users or groups assigned" and loading applications returns "Unauthorized." Set `argocd_rbac_role_mappings` in `terraform.tfvars` with at least one entry (e.g. `role = "ADMIN"`, `identity = [{ type = "SSO_GROUP", id = "<idc-group-id>" }]`). Roles are **ADMIN**, **EDITOR**, **VIEWER** only (no custom global roles). Get IdC user/group IDs from the IAM Identity Center console (Users/Groups) or ask your IdC admin—you don't need to manage IdC, only reference an existing identity by ID. EDITOR and VIEWER need [project roles](https://docs.aws.amazon.com/eks/latest/userguide/argocd-permissions.html) (AppProject in-cluster) to access Applications; ADMIN has full access. For repository access (e.g. GitHub via CodeConnections), attach the required IAM policies to the capability role via the root module's `capabilities.argocd.iam_policy_arns`; see [Configure repository access](https://docs.aws.amazon.com/eks/latest/userguide/argocd-configure-repositories.html).

## Prerequisites

- AWS provider >= 6.0 (for `aws_eks_capability`).
- If using Argo CD: [Identity Center (IdC)](https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html) must be set up; provide the IdC instance ARN in `argocd_idc_instance_arn`.

This example uses the module default `cluster_authentication_mode = "API_AND_CONFIG_MAP"`, which is required when using EKS Capabilities. You do not need to set it explicitly unless overriding.

## Best practices

- **ACK IAM:** The example uses `AmazonS3FullAccess` for simplicity. For production, use least-privilege IAM policies or [IAM Role Selectors](https://docs.aws.amazon.com/eks/latest/userguide/ack-permissions.html) for namespace-scoped permissions.
- **Cost allocation:** Capability resources accept tags (the module passes `var.tags`). Tagging with cluster name and capability type helps with cost allocation (see [EKS Capabilities pricing](https://docs.aws.amazon.com/eks/latest/userguide/capabilities.html#capabilities-pricing)).

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and set your values (IdC instance ARN if using Argo CD, access entries, etc.). Add `terraform.tfvars` to `.gitignore` if it contains account-specific data.
2. Run Terraform:

```bash
terraform init
terraform plan
terraform apply
```

### If first apply fails with "Provider produced inconsistent final plan" (NACL)

The AWS provider can mis-correlate `aws_network_acl` ingress/egress set elements on first apply. Optional workaround: apply the VPC first, then the rest:

```bash
terraform apply -target=module.vpc
terraform apply
```

## Module support for EKS capabilities

The root module supports what’s needed for EKS capabilities:

- **ACK:** Optional `role_arn` or module-created role; `iam_policy_arns` for controller policies; optional `access_entry_policy_associations` for EKS access entry policies (e.g. `AmazonEKSSecretReaderPolicy`).
- **KRO:** No IAM required; no extra config.
- **Argo CD:** `configuration.argo_cd` with `aws_idc` (required), `rbac_role_mapping`, `namespace`, and `network_access` (vpce_ids). Optional `iam_policy_arns` on the capability for CodeConnections, Secrets Manager, or ECR (see [Configure repository access](https://docs.aws.amazon.com/eks/latest/userguide/argocd-configure-repositories.html)). Optional `role_arn` to use your own role.

EKS automatically creates an access entry for each capability role and attaches the default managed policies (e.g. `AmazonEKSArgoCDClusterPolicy`, `AmazonEKSArgoCDPolicy` for Argo CD). The module does not need to create those.

## Further reading

- [EKS Capabilities](https://docs.aws.amazon.com/eks/latest/userguide/capabilities.html)
- [Security considerations for EKS Capabilities](https://docs.aws.amazon.com/eks/latest/userguide/capabilities-security.html) – IAM least privilege, access entries, namespace isolation
- [Working with capability resources](https://docs.aws.amazon.com/eks/latest/userguide/working-with-capabilities.html)
- [EKS Capabilities considerations](https://docs.aws.amazon.com/eks/latest/userguide/capabilities-considerations.html)
- [Configure ACK permissions](https://docs.aws.amazon.com/eks/latest/userguide/ack-permissions.html)
- [Configure Argo CD permissions](https://docs.aws.amazon.com/eks/latest/userguide/argocd-permissions.html) – RBAC and project roles
- [Configure repository access](https://docs.aws.amazon.com/eks/latest/userguide/argocd-configure-repositories.html) – GitHub (CodeConnections), Secrets Manager, ECR

## Outputs

- `cluster_name` – EKS cluster name
- `cluster_capabilities` – Map of EKS capability resources
- `cluster_capability_role_arns` – IAM role ARNs for capabilities (e.g. for ACK controller configuration)
