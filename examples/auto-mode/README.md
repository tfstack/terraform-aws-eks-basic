# EKS Auto Mode Example

This example creates an EKS cluster with **EKS Auto Mode** enabled. Compute is managed by AWS; no managed node groups are defined.

## Requirements

- Kubernetes 1.29+ (required for Auto Mode)
- Terraform >= 1.6.0
- AWS provider >= 6.0

## Usage

1. Ensure you have AWS credentials configured.
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and set `access_entries` (required for kubectl access; see the example for admin, viewer, and namespace-scoped entries).
3. Run:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## What's created

- A VPC (via `cloudbuildlab/vpc/aws`) with public and private subnets
- An EKS cluster with:
  - **Auto Mode** enabled (`enable_automode = true`)
  - Built-in node pools: `system` and `general-purpose` (nodes are provisioned when you deploy workloads)
  - No `eks_managed_node_groups` (mutually exclusive with Auto Mode)
- No addons (CoreDNS, vpc-cni, kube-proxy, and **Pod Identity Agent** are built into Auto Mode; you do not install them).

## Verifying Auto Mode scaling

This repo only contains Terraform. After `apply`, use your own workloads (e.g. GitOps in a separate repository) or a quick ad hoc deployment to confirm nodes appear when pods are scheduled:

```bash
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region $(terraform output -raw aws_region)
kubectl get nodes -w
# In another terminal, deploy something (your manifests, Helm chart, or e.g.):
# kubectl create deployment demo --image=nginx --replicas=5
```

You should see nodes join as pods become schedulable. This example does not ship Kubernetes YAML.

## Notes

- Auto Mode requires Kubernetes 1.29 or later.
- Not available in AWS GovCloud or China regions.
- After apply, deploy workloads as usual; EKS will provision nodes automatically.
