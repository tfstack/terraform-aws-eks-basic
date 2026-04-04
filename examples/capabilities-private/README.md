# EKS Capabilities Private (in-VPC only)

This example is based on [eks-capabilities](../eks-capabilities). It is **private-only**: the EKS API and Argo CD are reachable **only from within the VPC**.

- **EKS API**: `endpoint_public_access = false`. Reachable only from inside the VPC.
- **Argo CD capability**: `network_access.vpce_ids` set so it is reachable only via the cluster VPC’s interface endpoint (private DNS in the VPC).
- **EKS, EKS Auth, EKS Capabilities** VPC endpoints (PrivateLink) so API and Argo CD work from inside the VPC without internet.
- **Jumphost**: SSM-managed instance in the VPC; use Session Manager to connect and access Argo CD or run `kubectl` from inside the VPC.

Use this example when EKS and Argo CD must be private and you are fine with access only from resources in the same VPC (e.g. the jumphost).

## Prerequisites

- **VPC module**: [cloudbuildlab/vpc/aws](https://registry.terraform.io/modules/cloudbuildlab/vpc/aws) **>= 1.0.28** with `enable_eks_capabilities_endpoint`. For the EKS endpoint security group, the module should support `eks_endpoint_allowed_cidrs` (see [VPC_MODULE_EKS_ENDPOINT_CIDRS.md](VPC_MODULE_EKS_ENDPOINT_CIDRS.md)).
- Same as [eks-capabilities](../eks-capabilities): AWS provider >= 6.0; if using Argo CD, [Identity Center (IdC)](https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html) and `argocd_idc_instance_arn`.

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and set your values (IdC instance ARN if using Argo CD, access entries).
2. Run:

```bash
terraform init
terraform plan
terraform apply
```

## Accessing Argo CD and the cluster

Connect from **inside the VPC** only:

1. Use **SSM Session Manager** to connect to the jumphost (no SSH key or bastion port needed).
2. From the jumphost, open the Argo CD URL (from `cluster_capabilities`, e.g. `https://<hash>.eks-capabilities.<region>.amazonaws.com`) in a browser, or run `kubectl` after configuring it to use the cluster.

The EKS capabilities hostname resolves to the VPC endpoint’s private IPs via the VPC’s default DNS when you are in the VPC.

## Variables

Same as [eks-capabilities](../eks-capabilities); no extra variables for this example.

## Outputs

Same as [eks-capabilities](../eks-capabilities): `cluster_name`, `cluster_capabilities`, `cluster_capability_role_arns`.

## Access entries

When changing capabilities or VPC endpoint configuration, you may need to clean up leftover EKS access entries. See [EKS_CAPABILITIES_ACCESS_ENTRIES.md](../../EKS_CAPABILITIES_ACCESS_ENTRIES.md).

## Further reading

- [EKS Capabilities](https://docs.aws.amazon.com/eks/latest/userguide/capabilities.html)
- [Access Amazon EKS using AWS PrivateLink](https://docs.aws.amazon.com/eks/latest/userguide/vpc-interface-endpoints.html)
