# Basic EKS Example

This example demonstrates how to create a basic EKS cluster with EC2 managed node groups using the `terraform-aws-eks-basic` module.

## Usage

1. **Set required variables:**

   Create a `terraform.tfvars` file or set environment variables:

   ```hcl
   aws_region    = "ap-southeast-2"
   cluster_name  = "my-eks-cluster"
   ```

   Note: This example creates a VPC automatically using the `cloudbuildlab/vpc/aws` module.
   You don't need to provide `vpc_id` or `subnet_ids` - they are created by the VPC module.

2. **Initialize Terraform:**

   ```bash
   terraform init
   ```

3. **Review the plan:**

   ```bash
   terraform plan
   ```

4. **Apply the configuration:**

   ```bash
   terraform apply
   ```

## Configuration

### Required Variables

- `cluster_name`: Name of the EKS cluster (default: `cltest`)
- `aws_region`: AWS region for resources (default: `ap-southeast-2`)

### VPC Configuration

This example automatically creates a VPC with:

- 2 availability zones
- Public and private subnets in each AZ
- Internet Gateway and NAT Gateway for internet access
- EKS-optimized tags for subnet discovery

### Optional Variables

- `cluster_name`: Name of the EKS cluster (default: `example-eks-cluster`)
- `cluster_version`: Kubernetes version (default: `1.28`)
- `node_instance_types`: EC2 instance types for nodes (default: `["t3.medium"]`)
- `node_desired_size`: Desired number of nodes (default: `2`)
- `node_min_size`: Minimum number of nodes (default: `1`)
- `node_max_size`: Maximum number of nodes (default: `3`)
- `node_disk_size`: Disk size in GiB (default: `20`)
- `enable_ebs_csi_driver`: Enable EBS CSI Driver addon (default: `false`)
- `enable_aws_lb_controller`: Enable AWS Load Balancer Controller (default: `false`)

## Outputs

After applying, you'll get outputs including:

- `cluster_name`: Name of the EKS cluster
- `cluster_endpoint`: Endpoint URL for the Kubernetes API server
- `cluster_ca_data`: Base64 encoded certificate authority data
- `oidc_provider_arn`: ARN of the OIDC provider for IRSA
- `node_group_id`: ID of the managed node group
- `node_role_arn`: IAM role ARN for EC2 nodes

## Connecting to the Cluster

After the cluster is created, configure `kubectl`:

```bash
aws eks update-kubeconfig --name <cluster_name> --region <aws_region>
```

Verify connection:

```bash
kubectl get nodes
```

## Next Steps

- Configure AWS Auth to allow IAM users/roles to access the cluster
- Deploy applications to the cluster
- Enable additional addons (EBS CSI Driver, Load Balancer Controller) as needed
- Explore Fargate or AutoMode compute options
