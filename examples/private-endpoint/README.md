# Private API endpoint example

This example creates an EKS cluster with **private API only** (`endpoint_public_access = false`): VPC, EKS, and VPC interface endpoints for the EKS AWS API (PrivateLink). Route 53 and custom DNS are not included; use your own DNS or the default EKS endpoint hostname from a network that can reach the private endpoint.

## Private endpoint

The cluster has no public API endpoint. Terraform and Helm in this example use `module.eks.cluster_endpoint`; they must run from a network that can reach the private API (e.g. VPN into the VPC).

## EKS API PrivateLink (interface endpoints)

The example enables the VPC module’s **EKS API** and **EKS Auth** interface endpoints (`enable_eks_endpoint = true`, `enable_eks_auth_endpoint = true`) per [Access Amazon EKS using AWS PrivateLink](https://docs.aws.amazon.com/eks/latest/userguide/vpc-interface-endpoints.html). Those endpoints allow **EKS API actions** (Terraform, AWS CLI, SDK) from inside the VPC without internet. They **do not** provide access to the **Kubernetes API** (kubectl); kubectl uses the cluster endpoint. Private DNS is enabled in the VPC so `eks.<region>.amazonaws.com` resolves via the endpoint. [AWS PrivateLink pricing](https://aws.amazon.com/privatelink/pricing/) applies. To omit the EKS Auth endpoint, set `enable_eks_auth_endpoint = false` in the VPC module call.

## How to connect (private-only)

Prerequisites: a path into the VPC (e.g. VPN) and DNS so the cluster API hostname resolves to the **private** endpoint IP (e.g. VPC DNS when on VPN, or your own private zone).

### 1. Get kubeconfig

From a machine that can reach the private API (e.g. laptop on VPN):

```bash
aws eks update-kubeconfig --region <region> --name <cluster_name>
```

### 2. Use the default API server or your own DNS

- **Default hostname**: If your DNS (e.g. VPC Resolver when on VPN) resolves the EKS endpoint hostname to the private IP, use the kubeconfig as-is. TLS works because the certificate matches `*.eks.<region>.amazonaws.com`.
- **Custom hostname**: If you use a custom FQDN for the API (your own DNS), set the cluster `server` in `~/.kube/config` to `https://<your-fqdn>` and add `insecure-skip-tls-verify: true` for that cluster (the EKS cert does not match custom names).

Then run `kubectl get nodes` (with AWS credentials if needed, e.g. `aws-vault exec dev -- kubectl get nodes`) to confirm API access.

## Usage

- Run `terraform init`, `terraform plan`, `terraform apply`.
- Connect from a network that can reach the private endpoint (e.g. VPN). Use `cluster_endpoint` or `cluster_endpoint_hostname` outputs if needed.
