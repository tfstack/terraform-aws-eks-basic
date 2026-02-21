# Pod Identity Example (Terraform-only)

This example is **Terraform-only**: the EKS cluster and External DNS (namespace, service account, deployment) are all managed by Terraform. Do not deploy external-dns via ArgoCD or Helm in the same cluster/namespace or it will conflict.

- **AWS Load Balancer Controller** – IAM role + Pod Identity (deploy the Helm chart yourself into `aws-load-balancer-controller`).
- **External DNS** – IAM role + Pod Identity + deployment created by Terraform.
- **EBS CSI Driver addon** – IAM role + Pod Identity via `addon_service_accounts`.

## Requirements

- **eks-pod-identity-agent** addon is enabled in this example.

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## Terraform-only: remove ArgoCD external-dns

If ArgoCD currently deploys external-dns into this cluster, delete that Application so Terraform owns the deployment:

```bash
kubectl delete application external-dns -n argocd
```

Then run `terraform apply` so Terraform (re)creates the external-dns deployment.

## CloudWatch log group

When destroying this example, the CloudWatch log group for EKS control plane logs may need to be removed from Terraform state and deleted manually (e.g. if destroy fails or the resource is stuck):

```bash
terraform state rm 'module.eks.aws_cloudwatch_log_group.this[0]'
# Then delete the log group in the AWS console or via AWS CLI if desired:
# aws logs delete-log-group --log-group-name /aws/eks/<cluster-name>/cluster
```

## Key variables

| Variable | Purpose |
| -------- | ------- |
| `aws_load_balancer_controller_identity_type` | `pod_identity` |
| `external_dns_identity_type` | `pod_identity` |
| `addon_identity_type` | `pod_identity` |
| `addon_service_accounts` | Namespace/SA per addon (e.g. EBS CSI) |
| `external_dns_domain_filter` | Domain filter (e.g. `dev.example.com`) |
| `external_dns_txt_owner_id` | TXT owner ID (e.g. cluster name) |
| `external_dns_aws_zone_type` | `public` or `private` |
