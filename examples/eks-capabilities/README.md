# EKS Capabilities Example

This example demonstrates how to use EKS Capabilities (ACK, KRO, and ArgoCD) for platform engineering. It shows how platform teams can create reusable abstractions and how development teams can deploy applications with AWS resources using simple Kubernetes manifests.

## What This Example Creates

1. **EKS Cluster** with capabilities enabled:
   - **ACK** (AWS Controllers for Kubernetes) - Create AWS resources via Kubernetes manifests
   - **KRO** (Kube Resource Orchestrator) - Platform engineering abstractions
   - **ArgoCD** - GitOps capability for continuous deployment (disabled by default in this example)

2. **KRO Resource Graph Definition (RGD)** - Platform team abstraction template
3. **KRO Resource Group Instance** - Developer-facing application deployment
4. **KRO-managed AWS resources** - DynamoDB table and IAM role/policy created by the WebAppStack
5. **ACK example resources** - DynamoDB table and S3 bucket created via ACK manifests

## Features Demonstrated

- ✅ EKS Capabilities enablement (ACK, KRO, optional ArgoCD)
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
```

### Step 2: Initialize and Apply

```bash
terraform init
terraform plan
```

Because this example uses the Kubernetes provider (which needs a live cluster),
apply it in two stages:

```bash
# 1) Create the EKS cluster first
terraform apply -target=module.eks -auto-approve

# 2) Apply the rest (KRO/ACK resources, RGD, etc.)
terraform apply -auto-approve
```

Wait for the cluster and capabilities to be fully provisioned (this may take 10-15 minutes).

**Note:** The module automatically creates IAM roles for enabled capabilities (ACK, KRO, and ArgoCD if you enable it) with the appropriate managed policies. If you prefer to use existing roles, you can provide them via the `*_capability_role_arn` variables.

### Step 3: Configure kubectl

```bash
aws eks update-kubeconfig --name <cluster_name> --region <aws_region>
```

### Step 4: Verify Kubernetes Resources

The Terraform deployment automatically creates:

- **KRO RBAC Configuration** - Grants the KRO capability role cluster-admin permissions
- **KRO Resource Graph Definition (RGD)** - Platform team abstraction template
- **ACK Example Resources** - DynamoDB table and S3 bucket

These are automatically deployed as part of `terraform apply`. Verify they exist:

```bash
# Check KRO RBAC
kubectl get clusterrolebinding eks-capabilities-kro-cluster-admin

# Check KRO RGD
kubectl get resourcegraphdefinition eks-capabilities-appstack.kro.run
# Check ACK example resources
kubectl get table eks-capabilities-table
kubectl get bucket eks-capabilities-bucket
```

### Step 5: Verify Capabilities

Check that capabilities are active:

```bash
# Check available APIs
kubectl api-resources | grep -E "(resourcegraphdefinition|webappstack|podidentityassociation|table|bucket|role.iam.services.k8s.aws|policy.iam.services.k8s.aws)"

# Verify KRO API
kubectl get resourcegraphdefinition
```

### Step 6: Verify Resource Graph Definition

The RGD was automatically created by Terraform. Verify it:

```bash
kubectl get resourcegraphdefinition eks-capabilities-appstack.kro.run
kubectl describe resourcegraphdefinition eks-capabilities-appstack.kro.run
```

**Expected output:**

- The RGD should show `STATE: Inactive` initially (KRO is processing it)
- Once active, the `WebAppStack` API will be available for use
- The `describe` command shows the full RGD definition with all resources

### Step 7: Deploy Application (Development Team)

The development team uses the abstraction to deploy their application:

```bash
kubectl apply -f kubernetes/dev-team/eks-capabilities-app-instance.yaml
```

Watch the resources being created:

```bash
kubectl get webappstack eks-capabilities-app -w
```

Wait for the deployment to be ready (about 1-2 minutes), then test the application:

```bash
# Port forward for quick testing
kubectl port-forward service/eks-capabilities-app 8080:80
```

Then open <http://localhost:8080> in your browser.

### Step 8: Verify WebAppStack Resources

The WebAppStack creates the AWS resources needed by the demo app. Verify they exist:

```bash
# DynamoDB table used by the app
kubectl get table eks-capabilities-app

# IAM role and policy used by Pod Identity
kubectl get role.iam.services.k8s.aws eks-capabilities-app-role
kubectl get policy.iam.services.k8s.aws eks-capabilities-app-policy

# Pod Identity Association
kubectl get podidentityassociation eks-capabilities-app

# Optional S3 bucket (only if bucket.enabled=true)
kubectl get bucket eks-capabilities-app-bucket

# Keep this name distinct from the ACK example bucket (eks-capabilities-bucket)

```

### Step 9: Verify ACK Example Resources

The ACK example resources are created independently of the WebAppStack:

```bash
# DynamoDB table and S3 bucket created via ACK manifests
kubectl get table eks-capabilities-table
kubectl get bucket eks-capabilities-bucket

```

## Understanding the Components

### KRO Resource Graph Definition (RGD)

The RGD template in `kubernetes/platform-team/eks-capabilities-appstack-rgd.yaml.tpl` defines:

- **Schema**: Developer-facing API (WebAppStack)
- **Resources**: Multiple Kubernetes and AWS resources bundled together
- **Dependencies**: Automatic dependency resolution
- **Conditional Resources**: S3 bucket and Ingress only created when enabled

### KRO Resource Group Instance

The instance in `kubernetes/dev-team/eks-capabilities-app-instance.yaml` shows:

- Simple developer interface
- Single manifest deploys multiple resources
- Automatic resource creation and dependency management

### KRO-managed AWS Resources

The WebAppStack uses ACK-backed resources under the hood:

- DynamoDB table for app state
- Optional S3 bucket when enabled
- IAM role/policy for Pod Identity

## Verifying the Deployment

### Check Application Status

```bash
# Check the WebAppStack instance
kubectl get webappstack eks-capabilities-app -o yaml

# Check deployment
kubectl get deployment eks-capabilities-app

# Check service
kubectl get service eks-capabilities-app

# Check DynamoDB table
kubectl get table eks-capabilities-app

# Check IAM role and policy (ACK)
kubectl get role.iam.services.k8s.aws eks-capabilities-app-role
kubectl get policy.iam.services.k8s.aws eks-capabilities-app-policy
```

### Check Pod Identity

```bash
# Verify Pod Identity Association
kubectl get podidentityassociation eks-capabilities-app

# Check ServiceAccount
kubectl get serviceaccount eks-capabilities-app -o yaml
```

### Access the Application

#### Option 1: Port Forward (Quick Test)

```bash
kubectl port-forward service/eks-capabilities-app 8080:80
```

Then open <http://localhost:8080> in your browser.

#### Option 2: ALB (Production)

```bash
kubectl get ingress eks-capabilities-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## ArgoCD Capability

The ArgoCD capability is disabled by default in this example. If you enable it, it provides:

- Managed ArgoCD installation
- GitOps workflow support
- Application synchronization from Git repositories

For full ArgoCD setup, refer to AWS documentation or future examples.

## Cleanup

To clean up all resources:

```bash
# Delete the application instance (cascades to all resources)
kubectl delete webappstack eks-capabilities-app

# Delete ACK example resources
kubectl delete -f kubernetes/ack-resources/

# Destroy Terraform resources (this will also delete RBAC and RGD)
terraform destroy
```

## Troubleshooting

### Capabilities Not Active

If capabilities show as "CREATING" for a long time:

```bash
# Check capability status
aws eks describe-capability --cluster-name <cluster-name> --capability-name ACK
aws eks describe-capability --cluster-name <cluster-name> --capability-name KRO
aws eks describe-capability --cluster-name <cluster-name> --capability-name ARGOCD
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
- Set up ArgoCD for GitOps workflows
- Implement namespace-specific IAM roles using IAMRoleSelector
- Create additional platform abstractions for different application types

## References

- [EKS Capabilities Documentation](https://docs.aws.amazon.com/eks/latest/userguide/capabilities.html)
- [ACK Documentation](https://aws-controllers-k8s.github.io/community/)
- [KRO Documentation](https://kro.dev/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
