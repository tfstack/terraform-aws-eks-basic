# EKS Auto Mode (existing VPC, private endpoint)

This example creates an EKS cluster with **EKS Auto Mode** on an **existing VPC**. The API endpoint is **private only** (`endpoint_public_access = false`); the cluster is reachable only from within the VPC or via VPN/PrivateLink. No VPC module is used; you pass `vpc_id` and `subnet_ids`.

## Requirements

- Kubernetes 1.29+ (required for Auto Mode)
- Terraform >= 1.6.0
- AWS provider >= 6.0
- An existing VPC with subnets suitable for EKS (e.g. private subnets)

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars`.
2. Set `vpc_id` and `subnet_ids` to your existing VPC and subnets (e.g. private subnet IDs).
3. Set `access_entries` for cluster access (required for kubectl).
4. Run `terraform init`, `terraform plan`, `terraform apply`.

## What's created

- An EKS cluster with **private API endpoint only** (no public access), Auto Mode (`enable_automode = true`), node pools `system` and `general-purpose`, EBS CSI driver (Pod Identity). No managed node groups; no addons (built into Auto Mode).

## Variables

| Variable                  | Description                                           |
| ------------------------- | ----------------------------------------------------- |
| `vpc_id`                  | ID of the existing VPC (required)                     |
| `subnet_ids`              | Subnet IDs for the cluster (required)                 |
| `cluster_name`            | EKS cluster name                                      |
| `cluster_version`         | Kubernetes version (1.29+ for Auto Mode)              |
| `access_entries`          | Access entries for cluster access (required)          |
| `argocd_idc_instance_arn` | When set, enables Argo CD + CodeConnections (optional)|

## Connecting

The API is private-only. Use kubectl from **inside the VPC** (e.g. a jumphost, EC2 instance, or VPN that routes the VPC CIDR):

```bash
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region $(terraform output -raw aws_region)
```

Use `manifests/scale-test.yaml` to trigger Auto Mode scaling (deploy a workload and watch nodes appear).

## Argo CD and CodeConnections

When Argo CD is enabled, this example wires the **argocd-codeconnections** submodule so Argo CD can pull from GitHub via CodeConnections. After apply, complete the GitHub connection in the AWS Console.

- **Repository list (one-time):** Add a repo in Argo CD Settings → Repositories. URL must use the connection **UUID** (not the ARN). From this directory, with kubeconfig set:

  ```bash
  export REGION=$(terraform output -raw aws_region)
  export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
  export CONN_ID=$(terraform output -json argocd_connection_ids | jq -r '.github')
  export OWNER_REPO="my-org/my-repo"   # your org and repo
  kubectl create secret generic argocd-repo-github -n argocd --from-literal=url="https://codeconnections.${REGION}.amazonaws.com/git-http/${ACCOUNT}/${REGION}/${CONN_ID}/${OWNER_REPO}.git"
  kubectl label secret argocd-repo-github -n argocd argocd.argoproj.io/secret-type=repository
  ```

- **Applications:** Set Application `source.repoURL` to the CodeConnections URL (from `terraform output -raw argocd_repo_url_template`, replacing `OWNER/REPO` with your repo).

### Argo CD repo: verify and troubleshoot

- **Connection status:** AWS Console → Developer Tools → Connections → **Available**. If Pending, complete the GitHub auth flow.
- **URL format:** `https://codeconnections.<region>.amazonaws.com/git-http/<account>/<region>/<connection-uuid>/<owner>/<repo>.git`. The path must use the connection **UUID** (from `argocd_connection_ids`), not the ARN—ARN in the path causes **400**. Check: `kubectl get secret argocd-repo-github -n argocd -o jsonpath='{.data.url}' | base64 -d; echo`
- **IAM:** Argo CD role has `codeconnections:UseConnection` and `codeconnections:GetConnection` (handled by the submodule). After IAM changes, re-apply and wait before refreshing in Argo CD.
