# EKS Auto Mode + workload AWS auth (SQS)

This example creates an EKS cluster with **EKS Auto Mode** enabled, and demonstrates **Terraform-side workload IAM wiring** for an application ServiceAccount that needs **SQS** access.

It is suitable for KEDA-managed workers (or any worker) that consumes from SQS.

## Requirements

- Kubernetes 1.29+ (required for Auto Mode)
- Terraform >= 1.6.0
- AWS provider >= 6.0

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and set `access_entries` (required for kubectl access).
2. Run:

```bash
terraform init
terraform plan
terraform apply
```

## What this example demonstrates

- **Pod Identity** for workload pods by default (Auto Mode includes the Pod Identity agent).
- A workload ServiceAccount binding (namespace + service account name) to an IAM role with least-privilege **SQS consumer** permissions.

## Switching to IRSA

Set `sqs_identity_type = "irsa"` in the `module "eks"` inputs.

When using IRSA, you must also ensure your Kubernetes ServiceAccount is annotated with `eks.amazonaws.com/role-arn` (created/managed outside this Terraform module).
