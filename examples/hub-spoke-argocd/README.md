# EKS Argo CD Hub-and-Spoke Example

This example implements the [AWS hub-and-spoke GitOps pattern](https://docs.aws.amazon.com/eks/latest/userguide/argocd.html) using the managed EKS Argo CD capability.

One **hub** cluster hosts the Argo CD capability (with AWS IAM Identity Center authentication). Two **spoke** clusters (`module.eks_spoke_1` and `module.eks_spoke_2`) do not run Argo CD themselves — instead, they grant the hub's Argo CD IAM role cluster-admin access via `access_entries`, allowing Argo CD on the hub to deploy to them.

```text
Hub EKS (Argo CD + ACK + KRO)
  └─ deploys to ──► Spoke 1 — module eks_spoke_1 (ACK + KRO)
  └─ deploys to ──► Spoke 2 — module eks_spoke_2 (ACK + KRO)
```

All three clusters share one VPC.

## Requirements

- Terraform >= 1.6.0
- AWS provider >= 6.0
- **AWS IAM Identity Center** — required for the managed Argo CD capability (`argocd_idc_instance_arn`)
- Kubernetes 1.29+ (required for managed capabilities)

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in:
   - `argocd_idc_instance_arn` (required)
   - `access_entries_hub` / `access_entries_spoke_dev` / `access_entries_spoke_prod` for your IAM principals
   - `argocd_rbac_role_mappings` for Argo CD UI access
2. Run:

   ```bash
   cd examples/hub-spoke-argocd
   terraform init
   terraform plan
   terraform apply
   ```

> **Optional targeted apply:** If you want spoke clusters to be created after the hub IAM role exists (e.g. to avoid unknown-value diffs on first plan), run `terraform apply -target=module.eks_hub` first, then `terraform apply`. This is not required — Terraform resolves the dependency automatically.

## What's created

- A shared VPC with public and private subnets (2 AZs)
- **Hub EKS cluster** (default `cluster_names.hub` = `eks-10`) with:
  - **EKS Auto Mode** (`system` + `general-purpose` node pools; no managed node groups or addon map)
  - Capabilities: ACK, KRO, **Argo CD** (with IdC authentication, configurable RBAC, optional VPCE)
  - Argo CD capability role granted cluster-admin on the hub cluster itself (for in-cluster deployments)
- **Spoke 1** — `module.eks_spoke_1` (default `cluster_names.spoke_dev` = `eks-11`) with:
  - **EKS Auto Mode** (same node pools as hub)
  - Capabilities: ACK, KRO (no Argo CD)
  - Hub Argo CD role granted `AmazonEKSClusterAdminPolicy` via `access_entries`
- **Spoke 2** — `module.eks_spoke_2` (default `cluster_names.spoke_prod` = `eks-12`) — identical pattern to spoke 1
- **CodeConnections** (GitHub) on the hub only, granting the Argo CD role `UseConnection + GetConnection`

## Post-apply: register spoke clusters in Argo CD

After `terraform apply` completes:

1. Complete the GitHub OAuth handshake in the AWS Console → CodeConnections — new connections start in **PENDING** state.
2. Configure kubeconfig for the hub cluster:

   ```bash
   aws eks update-kubeconfig \
     --name "$(terraform output -raw hub_cluster_name)" \
     --region "$(terraform output -raw aws_region)"
   ```

3. Bootstrap GitOps on the hub using **kube-infra** (`bootstrap/root-eks-10.yaml` then `root-eks-11.yaml` / `root-eks-12.yaml`). All three root Applications sync to **`in-cluster`** on the hub — `clusters/eks-11` and `clusters/eks-12` are **ApplicationSets**, which must exist only on the hub (spokes lack the ApplicationSet CRD). Remote cluster Secrets still register eks-11/eks-12 for **child** apps. Managed Argo CD requires the **cluster ARN** (not the HTTPS API URL) in those Secrets’ `server` when using `awsAuthConfig`. Copy values from Terraform:

   ```bash
   terraform output -raw hub_cluster_arn
   terraform output -raw spoke_1_cluster_arn
   terraform output -raw spoke_2_cluster_arn
   terraform output -raw hub_argocd_capability_role_arn
   ```

   Pre-filled manifests live in the **kube-infra** repo under `bootstrap/`; after `git pull`, `kubectl apply` them to the hub context. See that repo’s `bootstrap/README.md` (hub-spoke section).

4. Argo CD Application `repoURL` must use the UUID from `argocd_connection_ids`:

   ```bash
   terraform output argocd_connection_ids
   ```

## Outputs

| Output | Description |
| --- | --- |
| `hub_cluster_name` | Hub cluster name |
| `hub_cluster_endpoint` | Hub API server endpoint |
| `hub_cluster_arn` | Hub EKS cluster ARN (Argo CD `server` for in-cluster registration) |
| `hub_argocd_capability_role_arn` | ARN of the hub Argo CD capability role (granted admin on all spokes) |
| `spoke_1_cluster_name` | First spoke cluster name (`eks_spoke_1`) |
| `spoke_1_cluster_endpoint` | First spoke API server endpoint |
| `spoke_1_cluster_arn` | First spoke EKS cluster ARN (Argo CD remote `Secret` `server`; not the HTTPS URL) |
| `spoke_2_cluster_name` | Second spoke cluster name (`eks_spoke_2`) |
| `spoke_2_cluster_endpoint` | Second spoke API server endpoint |
| `spoke_2_cluster_arn` | Second spoke EKS cluster ARN (Argo CD remote `Secret` `server`) |
| `argocd_connection_ids` | CodeConnections UUID map — use in Argo CD Application `repoURL` |
| `argocd_codeconnections_iam_role_name` | Hub IAM role with CodeConnections policy attached |

## Notes

- **Renaming modules in an existing workspace:** If state still has `module.eks_spoke_dev` / `module.eks_spoke_prod`, run before the next apply:

  ```bash
  terraform state mv 'module.eks_spoke_dev' 'module.eks_spoke_1'
  terraform state mv 'module.eks_spoke_prod' 'module.eks_spoke_2'
  ```

- **Least privilege in production:** Replace `AmazonEKSClusterAdminPolicy` with a narrower policy (e.g. namespace-scoped `AmazonEKSEditPolicy`) once you know which namespaces Argo CD deploys to.
- **KNOWN BUG — Argo CD UI public ↔ private switching:** Changing `argocd_vpce_ids` between empty and a VPCE ID does not apply in-place. Workaround: remove `argocd` from hub capabilities, `apply`, re-add with the correct `argocd_vpce_ids`, `apply` again.
- **`argocd_idc_instance_arn` is required** for this example. The whole hub-spoke wiring depends on the Argo CD capability role existing on the hub.
- **Subnet tags:** Spoke cluster tags (`kubernetes.io/cluster/<spoke>`) are merged into the VPC module's `tags` input to avoid conflicts with the `aws_subnet` resource in AWS provider v6.
- **Subnets for Auto Mode:** All clusters use **private** subnets only for `subnet_ids` (control plane still respects your public/private API settings).
