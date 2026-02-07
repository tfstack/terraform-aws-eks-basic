# Basic EKS Example

This example demonstrates how to create a basic EKS cluster with EC2 managed node groups using the `terraform-aws-eks-basic` module.

## Usage

1. **Configure variables:**

   Edit `terraform.tfvars` to set your cluster name and access entries:

   ```hcl
   cluster_name = "my-eks-cluster"
   aws_region   = "ap-southeast-2"
   ```

2. **Initialize and apply:**

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Configuration

### Variables

- `cluster_name`: Name of the EKS cluster (default: `cltest`)
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
