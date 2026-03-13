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

## Testing Auto Mode scaling

To confirm that Auto Mode provisions nodes when you schedule workloads:

1. Configure kubectl (run from the example dir):

   ```bash
   aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region $(terraform output -raw aws_region)
   ```

2. Deploy a minimal workload (triggers node provisioning):

   ```bash
   kubectl apply -f manifests/scale-test.yaml
   ```

3. In one terminal, watch nodes (Auto Mode will add nodes as pods are scheduled):

   ```bash
   kubectl get nodes -w
   ```

4. In another, watch pods:

   ```bash
   kubectl get pods -A -w
   ```

5. Scale up to see more nodes come in:

   ```bash
   kubectl scale deployment scale-test -n default --replicas=10
   ```

You should see new nodes appear within a few minutes as pending pods get scheduled. When done, scale to 0 or delete the deployment to allow nodes to scale down.

## Notes

- Auto Mode requires Kubernetes 1.29 or later.
- Not available in AWS GovCloud or China regions.
- After apply, deploy workloads as usual; EKS will provision nodes automatically.
