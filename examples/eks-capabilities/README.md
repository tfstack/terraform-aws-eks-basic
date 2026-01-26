# EKS Capabilities Example

This example demonstrates how to use EKS Capabilities (ACK and KRO) for platform engineering. It shows how platform teams can create reusable abstractions and how development teams can deploy applications with AWS resources using simple Kubernetes manifests.

**Note**: ArgoCD capability is scaffolded in the codebase but not currently supported as it requires AWS Identity Center configuration.

## What This Example Creates

1. **EKS Cluster** with capabilities enabled:
   - **ACK** (AWS Controllers for Kubernetes) - Create AWS resources via Kubernetes manifests
   - **KRO** (Kube Resource Orchestrator) - Platform engineering abstractions
   - **ArgoCD** - Scaffolded only (not supported - requires AWS Identity Center)

2. **KRO Resource Graph Definition (RGD)** - Platform team abstraction template
3. **KRO Resource Group Instance** - Developer-facing application deployment
4. **KRO-managed AWS resources** - DynamoDB table and IAM role/policy created by the WebAppStack
5. **ACK example resources** - DynamoDB table and S3 bucket created via ACK manifests

## Features Demonstrated

- ✅ EKS Capabilities enablement (ACK, KRO)
- ✅ Platform engineering with KRO Resource Graph Definitions
- ✅ Creating AWS resources (DynamoDB, S3, IAM) via ACK as part of the WebAppStack
- ✅ Creating additional ACK example resources via standalone manifests
- ✅ Pod Identity for secure AWS resource access
- ✅ Developer self-service with abstracted APIs

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.6.0
- kubectl installed
- AWS account with permissions to create EKS clusters and capabilities

## Usage

### Step 1: Configure Variables

Create a `terraform.tfvars` file:

```hcl
aws_region   = "ap-southeast-2"
cluster_name = "eks-capabilities"

# IMPORTANT: Add your IAM user/role ARNs to access the cluster
cluster_admin_arns = [
  "arn:aws:iam::YOUR_ACCOUNT:role/your-admin-role",
  "arn:aws:iam::YOUR_ACCOUNT:user/your-user"
]
```

**Note**: The `cluster_admin_arns` variable is required for cluster access. When EKS capabilities are enabled, the cluster uses `API_AND_CONFIG_MAP` authentication mode, which requires explicit access entries. Add the ARNs of IAM users/roles that need admin access to the cluster. The module automatically creates the access entries for you.

### Step 2: Initialize and Apply

```bash
terraform init
terraform plan
```

Because this example uses the Kubernetes provider (which needs a live cluster),
apply it in stages:

```bash
# 1) Create the EKS cluster first
terraform apply -target=module.eks -auto-approve

# 2) Apply KRO RBAC and RGD first (required for WebAppStack CRD validation)
terraform apply -target='kubernetes_manifest.kro_rbac' -target='kubernetes_manifest.kro_rgd' -auto-approve

# 3) Apply ACK resources (DynamoDB table, S3 bucket) - needed for IAM policy
terraform apply -target='kubernetes_manifest.ack_dynamodb_table' -target='kubernetes_manifest.ack_s3_bucket' -auto-approve

# 4) Apply WebAppStack instance (creates Pod Identity Association, then Deployment)
terraform apply -target='kubernetes_manifest.kro_webappstack_instance' -auto-approve

# 4.5) Wait for Pod Identity Association to be ready, then restart deployment
# Note: KRO's dependsOn ensures creation order but not readiness state. Pods created before
# the Pod Identity Association is fully ready won't have the required env vars. We wait for
# the association to be ready, then restart the deployment to ensure all pods get env vars.
kubectl wait --for=jsonpath='{.status.conditions[?(@.type=="Ready")].status}=True' \
  podidentityassociation/eks-capabilities-app --timeout=60s
kubectl rollout restart deployment/eks-capabilities-app

# 5) Apply any remaining resources (access entries, etc.)
terraform apply -auto-approve
```

Wait for the cluster and capabilities to be fully provisioned (this may take 10-15 minutes).

**Note:** The module automatically creates IAM roles for enabled capabilities and EKS access entries for `cluster_admin_arns` when you run `terraform apply`.

### Step 3: Configure kubectl and Verify Access

```bash
aws eks update-kubeconfig --name eks-capabilities --region ap-southeast-2
```

**Verify access entries were created:**

The access entries should have been created in Step 2. Verify they exist:

```bash
# Check your current IAM principal
aws sts get-caller-identity --query Arn --output text

# List all access entries for the cluster
aws eks list-access-entries --cluster-name eks-capabilities --region ap-southeast-2
```

If your ARN is not in the access entries list, run `terraform apply` to create the missing access entries. See the Troubleshooting section below for more details.

### Step 4: Verify Deployment

Verify that all resources were created successfully:

```bash
# Check capabilities are active
kubectl api-resources | grep -E "(resourcegraphdefinition|webappstack|podidentityassociation|table|bucket|role.iam.services.k8s.aws|policy.iam.services.k8s.aws)"

# Check KRO resources
kubectl get resourcegraphdefinition eks-capabilities-appstack.kro.run
kubectl get webappstack eks-capabilities-app

# Check ACK example resources
kubectl get table eks-capabilities-table eks-capabilities-app
kubectl get bucket eks-capabilities-bucket

# Check WebAppStack AWS resources
kubectl get role.iam.services.k8s.aws eks-capabilities-app-role
kubectl get policy.iam.services.k8s.aws eks-capabilities-app-policy
kubectl get podidentityassociation eks-capabilities-app
```

Wait for the WebAppStack to be ready (about 1-2 minutes), then test the application:

```bash
# Port forward for quick testing
kubectl port-forward service/eks-capabilities-app 8080:80
```

Then open <http://localhost:8080> in your browser.

## Understanding the Components

### KRO Resource Graph Definition (RGD)

The RGD template (`kubernetes/platform-team/eks-capabilities-appstack-rgd.yaml.tpl`) defines a reusable abstraction that bundles:

- Kubernetes resources (Deployment, Service, ServiceAccount)
- AWS resources via ACK (DynamoDB table, IAM role/policy, Pod Identity Association)
- Conditional resources (S3 bucket, Ingress when enabled)

### KRO WebAppStack Instance

The instance (`kubernetes/dev-team/eks-capabilities-app-instance.yaml`) demonstrates how developers use the abstraction with a simple manifest that automatically creates all required resources.

### Access the Application

**Port Forward (Quick Test):**

```bash
kubectl port-forward service/eks-capabilities-app 8080:80
```

**ALB (Production):**

```bash
kubectl get ingress eks-capabilities-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## ArgoCD Capability (Not Currently Supported)

The ArgoCD capability is **scaffolded in the code but not supported** for the following reason:

**Prerequisite**: AWS Identity Center (formerly AWS SSO) must be configured for ArgoCD authentication. Local users are not supported.

Once you have Identity Center configured, you can:

1. Uncomment the ArgoCD resources in `capabilities.tf` and `capabilities-iam.tf`
2. Provide Identity Center configuration via `argocd_capability_configuration`
3. Enable the capability with `enable_argocd_capability = true`

For more information, see [AWS EKS ArgoCD Documentation](https://docs.aws.amazon.com/eks/latest/userguide/argocd-considerations.html).

## Cleanup

To clean up all resources, you must delete Kubernetes resources **before** destroying the cluster:

**Important**: Delete KRO and ACK resources first (while cluster exists), then destroy Terraform infrastructure.

```bash
# Step 1: Delete KRO WebAppStack instance
# This cascades to delete all KRO-managed AWS resources (DynamoDB table, IAM role/policy, Pod Identity Association)
kubectl delete webappstack eks-capabilities-app

# Step 2: Delete WebAppStack-created AWS resources
# These are created by the RGD and may need explicit deletion
kubectl delete table eks-capabilities-app
kubectl delete bucket eks-capabilities-app-bucket 2>/dev/null || true  # Only if bucket.enabled=true

# Step 3: Delete ACK example resources
# Note: The ACK capability only supports delete_propagation_policy = "RETAIN",
# which means AWS resources are NOT automatically deleted when Kubernetes resources are deleted.
# You must manually delete AWS resources after deleting Kubernetes resources.

# Delete Kubernetes resources
kubectl delete table eks-capabilities-table
kubectl delete bucket eks-capabilities-bucket

# Manually delete AWS resources (required because RETAIN policy prevents automatic deletion)
aws dynamodb delete-table --table-name eks-capabilities-table --region ap-southeast-2
aws s3 rm s3://eks-capabilities-bucket --recursive 2>/dev/null || true
aws s3api delete-bucket --bucket eks-capabilities-bucket --region ap-southeast-2 2>/dev/null || true

# Step 4: Wait for AWS resources to be fully deleted
# Verify resources are gone:
kubectl get table,bucket,role.iam.services.k8s.aws,policy.iam.services.k8s.aws,podidentityassociation

# Step 5: Destroy Terraform resources in phases (reverse of apply)
# Phase 1: Destroy Kubernetes resources first (while cluster exists)
# This deletes KRO RBAC and Resource Graph Definition
# Note: WebAppStack instance was already deleted in Step 1
terraform destroy -target=kubernetes_manifest.kro_rbac \
  -target=kubernetes_manifest.capabilities_pod_identity_rbac \
  -target=kubernetes_manifest.capabilities_pod_identity_rbac_binding \
  -target=kubernetes_manifest.kro_rgd \
  -target=kubernetes_manifest.ack_dynamodb_table \
  -target=kubernetes_manifest.ack_s3_bucket

# Phase 2: Destroy the EKS cluster and all infrastructure
# This deletes EKS Capabilities (ACK and KRO), cluster, and all infrastructure
terraform destroy
```

**Note**: KRO/ACK resources create AWS resources (DynamoDB, S3, IAM) that must be deleted while the cluster exists. Terraform-managed resources (RBAC, RGD) and EKS capabilities are automatically deleted during `terraform destroy`.

Important: ACK Delete Propagation Policy

The ACK capability only supports `delete_propagation_policy = "RETAIN"` (this is the only valid value). This means:

- When you delete a Kubernetes resource (e.g., `kubectl delete table`), the **AWS resource is NOT deleted** - it's retained
- The resource-level annotation `services.k8s.aws/deletion-policy: Delete` does not override the capability-level policy
- You **must manually delete AWS resources** after deleting Kubernetes resources using AWS CLI commands

**Troubleshooting Cleanup**:

If resources are stuck or won't delete:

1. **Check resource status:**

   ```bash
   kubectl get webappstack eks-capabilities-app -o yaml
   kubectl describe table eks-capabilities-table
   kubectl describe bucket eks-capabilities-bucket
   ```

2. **If table is stuck in "Terminating" state, check for finalizers:**

   ```bash
   kubectl get table eks-capabilities-table -o jsonpath='{.metadata.finalizers}'
   ```

3. **Force delete if needed (use with caution):**

   ```bash
   # Remove finalizers to force delete Kubernetes resource
   # Note: With RETAIN policy, AWS resource will still exist and must be deleted manually
   kubectl patch webappstack eks-capabilities-app -p '{"metadata":{"finalizers":[]}}' --type=merge
   kubectl patch table eks-capabilities-table -p '{"metadata":{"finalizers":[]}}' --type=merge
   kubectl patch bucket eks-capabilities-bucket -p '{"metadata":{"finalizers":[]}}' --type=merge
   ```

4. **Manually delete AWS resources (required - RETAIN is the only supported policy):**

   ```bash
   # Delete DynamoDB table directly in AWS
   aws dynamodb delete-table --table-name eks-capabilities-table --region ap-southeast-2

   # Delete S3 bucket (must be empty first)
   aws s3 rm s3://eks-capabilities-bucket --recursive 2>/dev/null || true
   aws s3api delete-bucket --bucket eks-capabilities-bucket --region ap-southeast-2 2>/dev/null || true
   ```

5. **Verify AWS resources are deleted before proceeding:**

   ```bash
   # Check DynamoDB tables
   aws dynamodb list-tables --region ap-southeast-2

   # Check S3 buckets
   aws s3 ls

   # Check IAM roles
   aws iam list-roles --query 'Roles[?contains(RoleName, `eks-capabilities`)].RoleName'
   ```

## Troubleshooting

### Kubernetes Provider "Unauthorized" Error After Creating Access Entries

**Symptom**: After creating access entries, Kubernetes resources fail with `Error: Unauthorized`

**Cause**: When using `terraform apply -target`, the Kubernetes provider's auth token data source may not refresh. The token was generated before the access entries existed.

**Solution**: Run `terraform apply` again without `-target` to refresh all data sources and apply remaining resources:

```bash
terraform apply
```

The module now includes dependencies to ensure Kubernetes resources wait for access entries, but you still need to refresh the provider's auth token by running apply again.

### kubectl Authentication Errors

**Symptom**: `"the server has asked for the client to provide credentials"` or `"You must be logged in to the server"`

**Solution**:

1. **Check your IAM principal and access entries:**

   ```bash
   aws sts get-caller-identity --query Arn --output text
   aws eks list-access-entries --cluster-name eks-capabilities --region ap-southeast-2
   terraform state list | grep cluster_admins
   ```

2. **If your ARN is missing:**
   - Add it to `cluster_admin_arns` in `terraform.tfvars`
   - Run `terraform apply` to create the access entry

### Capabilities Not Active

If capabilities show as "CREATING" for a long time:

```bash
# Check capability status
aws eks describe-capability --cluster-name eks-capabilities --capability-name ACK
aws eks describe-capability --cluster-name eks-capabilities --capability-name KRO
# ArgoCD not currently supported
```

### KRO Resources Not Creating

1. Verify RBAC is configured correctly:

   ```bash
   kubectl get clusterrolebinding eks-capabilities-kro-cluster-admin
   ```

2. Check KRO capability status:

   ```bash
   kubectl get resourcegraphdefinition
   ```

3. Check for errors:

   ```bash
   kubectl describe resourcegraphdefinition eks-capabilities-appstack.kro.run
   kubectl get webappstack eks-capabilities-app -o yaml
   ```

### WebAppStack AWS Resources Not Creating

1. Verify the WebAppStack is active:

   ```bash
   kubectl get webappstack eks-capabilities-app -o yaml
   ```

2. Check the RGD and KRO reconciliation:

   ```bash
   kubectl describe resourcegraphdefinition eks-capabilities-appstack.kro.run
   ```

3. Review ACK resource status:

   ```bash
   kubectl describe table eks-capabilities-app
   kubectl describe role.iam.services.k8s.aws eks-capabilities-app-role
   kubectl describe policy.iam.services.k8s.aws eks-capabilities-app-policy
   kubectl describe podidentityassociation eks-capabilities-app
   kubectl describe bucket eks-capabilities-bucket

### ACK Example Resources Not Creating

1. Verify ACK capability is active
2. Check IAM permissions for the ACK capability role
3. Review ACK resource status:

   ```bash
   kubectl describe table eks-capabilities-table
   kubectl describe bucket eks-capabilities-bucket
   ```

## Next Steps

- Explore creating more complex RGDs with multiple AWS services
- Configure AWS Identity Center for ArgoCD capability (future)
- Implement namespace-specific IAM roles using IAMRoleSelector
- Create additional platform abstractions for different application types

## References

- [EKS Capabilities Documentation](https://docs.aws.amazon.com/eks/latest/userguide/capabilities.html)
- [ACK Documentation](https://aws-controllers-k8s.github.io/community/)
- [KRO Documentation](https://kro.dev/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
