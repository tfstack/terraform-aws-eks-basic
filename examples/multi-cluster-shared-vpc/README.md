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

## Fargate cluster: IRSA (ALB controller + SQS / KEDA)

[EKS Pod Identity is not supported for pods on Fargate](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html). This example uses **IRSA** (OIDC) for AWS API access from Fargate workloads where needed.

- **AWS Load Balancer Controller:** `aws_load_balancer_controller_identity_type = "irsa"`. After apply, use `terraform output -raw fargate_aws_load_balancer_controller_role_arn` for the controller ServiceAccount `eks.amazonaws.com/role-arn` (see `kube-infra` ALB overlay for eks-3).
- **Celery SQS + KEDA:** `enable_sqs_access = true` with **`sqs_identity_type = "irsa"`** on the Fargate module only. Classic and Auto Mode clusters keep **`sqs_identity_type = "pod_identity"`**. After apply, use **`terraform output -json fargate_sqs_role_arns`** — keys **`celery/celery-workload`** and **`keda/keda-operator`**. Annotate those Kubernetes ServiceAccounts in **kube-devops-apps** (celery eks-3 overlay) and **kube-infra** (KEDA eks-3 overlay) with `eks.amazonaws.com/role-arn: <arn>`. IAM role names follow `terraform-aws-eks-basic/sqs-iam.tf`: `<cluster_name>-sqs-<namespace>-<sa>-role` with `/` in the map key replaced by `-` (e.g. `eks-3-sqs-celery-celery-workload-role` when `cluster_names.fargate = "eks-3"`).

The **EKS Pod Identity Agent** add-on remains enabled on the Fargate cluster for consistency with other examples; it does **not** grant Pod Identity credentials to Fargate pods.

This example:

- Adds **Fargate profiles** for `kube-system`, `aws-load-balancer-controller`, `gatekeeper-system`, **`keda`**, **`workload_sqs`**, and the **default app** namespace (`fargate_namespace`, e.g. `app`). Profile selectors are in `main.tf`.
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
- `fargate_sqs_role_arns` — map of IRSA role ARNs for SQS (`celery/celery-workload`, `keda/keda-operator`) on the Fargate cluster.
