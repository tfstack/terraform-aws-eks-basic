# EKS Auto Mode Example

This example stands up an **EKS Auto Mode** cluster: AWS provisions and scales **compute** for the built-in node pools; you do **not** define `eks_managed_node_groups` in Terraform. Workloads use the default **`system`** and **`general-purpose`** capacity unless you target add-on capacity (for example the **Karpenter `NodePool`** manifests here, which reference Auto Mode’s built-in **`NodeClass`** `default`).

Around that core, the same root module wires optional **platform** pieces (EKS add-ons with **Pod Identity**, ALB controller, EBS CSI, Secrets Manager and SQS associations, ACK/KRO, optional Argo CD, and **optional** Headlamp OIDC via Cognito). Treat Headlamp as an add-on to the Auto Mode story, not the main subject of this README.

## Requirements

- **Kubernetes:** Auto Mode requires **1.29+** (this example defaults to **1.35** in `variables.tf`; override with `cluster_version` if needed).
- **Terraform:** `>= 1.6.0`
- **Providers** (see `terraform` block in `main.tf`):
  - `hashicorp/aws` `>= 6.0`
  - `hashicorp/kubernetes` `~> 2.30`
  - `hashicorp/tls` `~> 4.0`
  - `hashicorp/archive` `~> 2.4`

## Usage

1. Configure AWS credentials for the account and region you want (`aws_region`; default `ap-southeast-2`).
2. Copy `terraform.tfvars.example` to `terraform.tfvars`.
3. Set **`access_entries`** (required for `kubectl` unless you rely on other cluster access). The example file shows admin, optional viewer, and optional namespace-scoped patterns.
4. Optional — tune before first `apply`:
   - **API endpoint:** `endpoint_public_access`, `public_access_cidrs`, `private_access_cidrs` (see comments in `main.tf`).
   - **Argo CD capability:** set `argocd_idc_instance_arn` and `argocd_rbac_role_mappings`; optionally `argocd_vpce_ids` for a private UI. See `main.tf` for the known limitation when toggling public vs private Argo CD UI.
   - **Headlamp / Cognito:** `headlamp_hostnames`, SAML URL, and RBAC rules — see [Optional: Headlamp OIDC and SAML](#optional-headlamp-oidc-and-saml) (short); details live in `headlamp.tf` and `variables.tf`.
5. Run:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## EKS Auto Mode in this example

- **`enable_automode = true`** in the root module; **`automode_node_pools`** includes **`system`** and **`general-purpose`**.
- **No managed node groups** — Auto Mode and `eks_managed_node_groups` are mutually exclusive for this pattern.
- **Built-in control-plane adjacent pieces** (do not duplicate as classic self-managed add-ons here): CoreDNS, Amazon VPC CNI, `kube-proxy`, **Pod Identity Agent**, and the Auto Mode integration for compute and storage/load-balancing where applicable. See [Amazon EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/automode.html) for current behaviour and limits (for example **not** in GovCloud or China).
- **Extra EKS add-ons** in `main.tf` are **marketplace / CSI / observability** style components on top of Auto Mode (versions pinned there); they use **Pod Identity** where configured because the agent is available on Auto Mode nodes.

## What's created

### Networking

- A VPC (module `cloudbuildlab/vpc/aws`) with public and private subnets, single NAT gateway, and EKS subnet tags.

### EKS cluster (root module `../../`)

- Auto Mode cluster and pools as above; **cluster access** from `access_entries`.

### EKS add-ons (`addons` in `main.tf`)

Examples (see file for pinned versions): `aws-mountpoint-s3-csi-driver`, `aws-secrets-store-csi-driver-provider`, `cert-manager`, `external-dns`, `metrics-server`, `prometheus-node-exporter`, `aws-efs-csi-driver`, `aws-fsx-csi-driver`. **Pod Identity** backs several add-ons via `addon_identity_type` and `addon_service_accounts`.

### Controllers and AWS integrations

- **AWS Load Balancer Controller** with Pod Identity.
- **EBS CSI** with Pod Identity.
- **Secrets Manager** Pod Identity associations (including a Headlamp sync service account) and prefixes such as `headlamp/oidc`.
- **SQS** Pod Identity for Celery and KEDA service accounts; queue ARNs are derived from `cluster_name` in `main.tf` locals.

### EKS capabilities

- **ACK** and **KRO** are always in `capabilities` (ACK includes an SQS IAM policy for common GitOps patterns).
- **Argo CD** only if `argocd_idc_instance_arn` is set. When on, **`module.argocd_connections`** adds GitHub **CodeConnections** and IAM for the Argo CD capability role. Authorise new connections in the AWS console (`PENDING` until OAuth completes). Outputs: `argocd_connection_ids`, `argocd_codeconnections_iam_role_name`, `argocd_codeconnections_iam_policy_name`.

### Karpenter `NodePool` on Auto Mode (Kubernetes API)

Terraform applies two **`kubernetes_manifest`** resources after `module.eks` (see `karpenter-nodepool*.tf`, `manifests/`):

| NodePool | Role |
| --- | --- |
| `gpu` | Accelerated / NVIDIA (**g5/g6/g6e**), on-demand, GPU taint for isolation. |
| `batch-spot` | Spot-first batch-style general compute with on-demand fallback; caps and disruption in YAML. |

Both set `nodeClassRef` to Auto Mode **`NodeClass`** **`default`**. Remove or edit the `.tf` / YAML files if you do not want these pools.

### Cognito / Headlamp (supporting resources)

- Cognito user pool, app client, EKS **OIDC identity provider** for Headlamp, optional **SAML** IdP in Cognito, Pre Token Lambda, and Secrets Manager secret **`headlamp/oidc`**. SAML setup is summarised under [Optional: Headlamp OIDC and SAML](#optional-headlamp-oidc-and-saml).

## Verifying Auto Mode scaling

After `apply`, use the cluster endpoint from Terraform and watch nodes as you schedule pods:

```bash
aws eks update-kubeconfig --name "$(terraform output -raw cluster_name)" --region "$(terraform output -raw aws_region)"
kubectl get nodes -w
# Optional:
# kubectl create deployment demo --image=nginx --replicas=5
```

You should see nodes appear for the **built-in** pools when pending pods need capacity. **GPU** and **batch** shapes appear when workloads match the **Karpenter `NodePool`** requirements and tolerations.

## Optional: Headlamp OIDC and SAML

Headlamp in your GitOps repo consumes **Cognito** as OIDC issuer; this Terraform creates Cognito, wires **EKS `aws_eks_identity_provider_config`** (`username_claim = sub`, `groups_claim = cognito:groups`), and writes **`headlamp/oidc`** to Secrets Manager for the in-cluster sync.

**Typical SAML flow:**

1. **First apply** without `headlamp_saml_metadata_url` (and without legacy `headlamp_idc_saml_metadata_url`). Use IdP ACS / audience from:

   ```bash
   terraform output -raw headlamp_cognito_saml_acs_url
   terraform output -raw headlamp_cognito_saml_entity_id
   ```

2. Create your **Entra enterprise app** or **IAM Identity Center** SAML application using those values; map claims per `attribute_mapping` in `headlamp.tf` (email, name identifier, Microsoft groups claim for the Lambda).

3. In **`terraform.tfvars`:** set `headlamp_saml_metadata_url` to your IdP metadata URL; for Entra use `headlamp_saml_provider_name = "AzureAD"` (IdC default name is `IdentityCenter`). Set **`headlamp_hostnames`** if Headlamp is served on real hostnames (callbacks always include localhost for port-forward). Align **`headlamp_rbac_group_rules`** with your IdP groups and the `Group` names in your cluster RBAC (e.g. `kube-platform-apps` `apps/headlamp/base/rbac.yaml`).

4. **`terraform apply`**. If Cognito metadata URL changes later, you may need `-replace` on `aws_cognito_identity_provider.saml[0]` once (Terraform lifecycle ignores provider detail drift).

**If sign-in misbehaves:** duplicate **`openid`** in `OIDC_SCOPES` (secret should stay `email,profile`), **RelayState** missing on IdP-initiated Entra logins (prefer SP-initiated via Cognito hosted UI), or **callback URL** mismatch — see comments in `headlamp.tf` and [Cognito SAML behaviour](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-saml-idp-things-to-know.html).

## Notes

- Auto Mode requires Kubernetes **1.29+** and is **not** available in AWS GovCloud or China regions.
- **EBS CSI:** enabled with Pod Identity; the root module attaches `AmazonEBSCSIDriverEKSClusterScopedPolicy` and tags the driver role with **`eks-cluster-name`**.
