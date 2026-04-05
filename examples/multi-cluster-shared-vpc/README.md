# multi-cluster-shared-vpc

One **VPC** and **three** separate EKS clusters that share it:

| Cluster   | Compute mode        | Subnets used                          |
| --------- | ------------------- | ------------------------------------- |
| `classic` | EC2 managed nodes   | Public + private                      |
| `fargate` | Fargate profiles    | Public + private (profiles → private) |
| `automode` | EKS Auto Mode      | Private only                          |

Subnet tags: the VPC module sets `kubernetes.io/cluster/<classic>` = `shared` via `enable_eks_tags`. The fargate and automode cluster tags are merged into the VPC module's `tags` input so the `aws_subnet` resource owns all three tag keys — avoiding the perpetual drift that `aws_ec2_tag` causes when fighting `aws_subnet` in AWS provider v6.

## EBS CSI and kube-infra (`cluster_names`)

The default `terraform.tfvars.example` uses **classic = `eks-1`** and **automode = `eks-2`**. That matches **kube-infra** `infrastructure/aws-ebs-csi-driver/overlays/`: **`eks-1`** is the vendored driver + `ebs.csi.aws.com` (EC2 nodes); **`eks-2`** patches `ebs-sc` to **`ebs.csi.eks.amazonaws.com`** for EKS Auto Mode.

If you instead name your Auto Mode cluster `eks-1` and your classic cluster `eks-2`, swap those two keys in `cluster_names` **and** swap the EBS CSI overlay contents (or maintain cluster-specific overlays) so each cluster’s StorageClass matches its compute mode—otherwise PVCs (e.g. Headlamp) can sit in `VolumeBinding` until the scheduler times out.

## Argo CD

- Each cluster has its own **ACK / KRO / Argo CD** capability when `argocd_idc_instance_arn` is set.
- **Three** `argocd-codeconnections` modules create **three** GitHub connections (`github-<cluster_name>`). Use the matching output UUID in each cluster’s Argo CD `repoURL` (do not reuse another cluster’s connection).

Shared **tfvars** (one block for all three): `argocd_idc_instance_arn`, `argocd_rbac_role_mappings`, `argocd_vpce_ids`.

## Fargate cluster: AWS Load Balancer Controller (IRSA)

The **Fargate** cluster has no **Pod Identity** agent. For the AWS Load Balancer Controller (or any addon that needs AWS API access), use **IRSA** only.

This example:

- Adds **Fargate profiles** for `kube-system`, `aws-load-balancer-controller`, `gatekeeper-system`, **`keda`**, and the **default app** namespace (`fargate_namespace`, e.g. `app`).
- When **`argocd_idc_instance_arn` is set**, merges an **`argocd`** profile so the EKS **Argo CD** capability (namespace `argocd`) can schedule on this Fargate-only cluster.
- Sets `enable_aws_load_balancer_controller = true`, `aws_load_balancer_controller_identity_type = "irsa"`.

Add more profiles (or label selectors) for any other GitOps-managed namespace that must run on this cluster (e.g. `external-secrets`).

After `terraform apply`, use `terraform output -raw fargate_aws_load_balancer_controller_role_arn` for the Helm `eks.amazonaws.com/role-arn` annotation (or match the role name in `kube-infra` to your `cluster_names.fargate`).

## Cost and operations

Running three control planes and nodes/Fargate/Auto Mode is **expensive**. Use for demos or integration testing only.

```bash
cd examples/multi-cluster-shared-vpc
cp terraform.tfvars.example terraform.tfvars   # optional if you maintain terraform.tfvars locally (gitignored)
terraform init
terraform plan
```

### kubeconfig

```bash
aws eks update-kubeconfig --name $(terraform output -raw classic_cluster_name) --region $(terraform output -raw aws_region) --alias classic
aws eks update-kubeconfig --name $(terraform output -raw fargate_cluster_name) --region $(terraform output -raw aws_region) --alias fargate
aws eks update-kubeconfig --name $(terraform output -raw automode_cluster_name) --region $(terraform output -raw aws_region) --alias automode
```

## Outputs

- `classic_argocd_connection_ids`, `fargate_argocd_connection_ids`, `automode_argocd_connection_ids` — maps keyed by connection `name` (e.g. `github-eks-1`).
- `fargate_aws_load_balancer_controller_role_arn` — IRSA role for ALB controller on the Fargate cluster.
