# Basic EKS Example

This example demonstrates how to create a basic EKS cluster with EC2 managed node groups using the `terraform-aws-eks-basic` module.

## Usage

1. **Configure variables:**

   Edit `terraform.tfvars` (gitignored) or copy from `terraform.tfvars.example`. Cluster creator admin is enabled for the IAM identity that runs Terraform, so `access_entries` can stay `{}` at first. For additional principals, use real IAM ARNs in `access_entries` (12-digit account ID in the ARN; placeholder text like `ACCOUNT_ID` is rejected by AWS).

2. **Initialize and apply:**

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Configuration

### Variables

- `cluster_name`: Name of the EKS cluster (default: `eks-basic`)
- `aws_region`: AWS region for resources (default: `ap-southeast-2`)
- `cluster_version`: Kubernetes version (default: `1.35`)
- `access_entries`: Map of IAM users/roles with cluster access (default: `{}`)
- `tags`: Tags to apply to all resources

### VPC

This example automatically creates a VPC with public and private subnets using the `cloudbuildlab/vpc/aws` module.

### Node Groups

Node groups are configured in `main.tf` using the `eks_managed_node_groups` variable. The example includes one node group with 3 nodes.

### Addons

Core addons (CoreDNS, EKS Pod Identity Agent, kube-proxy, VPC-CNI) are configured in `main.tf`.

## Connecting to the Cluster

```bash
aws eks update-kubeconfig --name <cluster_name> --region <aws_region>
kubectl get nodes
```
