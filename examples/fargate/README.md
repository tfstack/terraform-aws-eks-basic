# EKS Fargate Example

This example creates an EKS cluster with **Fargate profiles only** (no EC2 managed node groups). Pods in `kube-system` and in the configured application namespace run on AWS Fargate.

## Requirements

- Terraform >= 1.6.0
- AWS provider >= 6.0

## Usage

1. Configure AWS credentials.
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and set `access_entries` (required for kubectl access).
3. Run:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## What's created

- A VPC (via `cloudbuildlab/vpc/aws`) with public and private subnets and a NAT gateway
- An EKS cluster using the root module with:
  - **CoreDNS** and **vpc-cni** addons (CoreDNS uses `computeType = "fargate"`)
  - **Fargate profiles** for `kube-system` and the namespace from `fargate_namespace` (default `app`)
  - No `eks_managed_node_groups` and no `enable_automode`

## Variables

- `cluster_name`: EKS cluster name (default: `eks-fargate`)
- `aws_region`: Region (default: `ap-southeast-2`)
- `cluster_version`: Kubernetes version (default: `1.35`)
- `fargate_namespace`: Namespace whose pods are scheduled on Fargate via the `default` profile (default: `app`)
- `access_entries`: Map of IAM principals for cluster access
- `tags`: Tags for resources
- Optional Argo CD + CodeConnections: set `argocd_idc_instance_arn` (IAM Identity Center instance ARN). The root module then creates the `argocd` capability so `cluster_capability_role_names["argocd"]` exists for `modules/argocd-codeconnections`. Use `argocd_rbac_role_mappings` / `argocd_vpce_ids` if needed (see `examples/eks-auto-mode-private`).

## Connecting to the cluster

```bash
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region $(terraform output -raw aws_region)
kubectl get pods -A
```

## Notes

- Fargate workloads need **private subnets with outbound internet** (NAT). This example uses private subnets for Fargate profile `subnet_ids`.
- For AWS API access from application pods, use **IRSA** (IAM Roles for Service Accounts). EKS Pod Identity is not supported on Fargate; see [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html).
- You can combine Fargate profiles with managed node groups or Auto Mode in the module for hybrid clusters; this example stays Fargate-only.
