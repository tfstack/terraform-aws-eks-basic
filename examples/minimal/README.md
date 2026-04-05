# minimal

Smallest possible usage of the root module: Auto Mode cluster with BYO VPC and subnets.

No capabilities, no Argo CD, no Secrets Manager, no EBS CSI driver.

Add features incrementally — see [examples/auto-mode](../auto-mode) for the full Auto Mode example.

From this directory: copy `terraform.tfvars.example` to `terraform.tfvars`, set `vpc_id` and `subnet_ids`, then `terraform init` / `plan` / `apply`.

## Usage

```hcl
module "eks" {
  source = "github.com/cloudbuildlab/terraform-aws-eks-basic"

  name               = "my-cluster"
  kubernetes_version = "1.35"
  vpc_id             = "vpc-xxxxxxxxxxxxxxxxx"
  subnet_ids         = ["subnet-aaa", "subnet-bbb"]

  enable_automode     = true
  automode_node_pools = ["system", "general-purpose"]
  addons              = {}
}
```

## Required inputs

| Name | Description |
| --- | --- |
| `vpc_id` | ID of an existing VPC |
| `subnet_ids` | List of subnet IDs (private subnets recommended) |

## Connect to the cluster

```bash
aws eks update-kubeconfig --region <region> --name <cluster_name>
```
