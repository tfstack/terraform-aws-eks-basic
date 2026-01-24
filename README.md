# terraform-aws-eks-basic

A basic Terraform module for creating and managing Amazon EKS (Elastic Kubernetes Service) clusters. Currently supports EC2 and Fargate; AutoMode is scaffolded only (no AutoMode-specific resources yet).

## Features

- **Multi-Compute Support**: Supports EC2 and Fargate; AutoMode is scaffolded
- **EC2 Managed Node Groups**: Full support for EC2 managed node groups with auto-scaling
- **Fargate Profiles**: Supported via `fargate_profiles` and Fargate IAM role creation
- **AutoMode**: Placeholder wiring only; no AutoMode-specific resources yet
- **IRSA Support**: OIDC provider setup for IAM Roles for Service Accounts
- **EKS Capabilities**: Managed ACK, KRO, and ArgoCD capabilities (optional, default: disabled)
  - **ACK**: AWS Controllers for Kubernetes - create AWS resources via Kubernetes manifests
  - **KRO**: Kube Resource Orchestrator - platform engineering abstractions
  - **ArgoCD**: GitOps capability for continuous deployment
- **Optional Addons**:
  - EBS CSI Driver (optional, default: disabled)
  - AWS Load Balancer Controller (optional, default: disabled)
- **Comprehensive Testing**: Includes Terraform test suite

## Prerequisites

| Name | Version |
| ---- | ------- |
| terraform | >= 1.6.0 |
| aws | >= 6.0 |
| kubernetes | ~> 2.30 |
| helm | ~> 2.13 |
| tls | ~> 4.0 |

## Usage

### Basic Example (EC2)

```hcl
module "eks" {
  source = "tfstack/eks-basic/aws"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.28"
  vpc_id          = "vpc-12345678"
  subnet_ids      = ["subnet-12345678", "subnet-87654321"]

  # EC2 compute mode (default)
  compute_mode = ["ec2"]

  # Node group configuration
  node_instance_types = ["t3.medium"]
  node_desired_size   = 2
  node_min_size       = 1
  node_max_size       = 3
  node_disk_size      = 20

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

### With Optional Addons

```hcl
module "eks" {
  source = "tfstack/eks-basic/aws"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.28"
  vpc_id          = "vpc-12345678"
  subnet_ids      = ["subnet-12345678", "subnet-87654321"]

  compute_mode = ["ec2"]

  # Enable optional addons
  enable_ebs_csi_driver   = true
  enable_aws_lb_controller = true

  tags = {
    Environment = "production"
  }
}
```

### With EKS Capabilities

```hcl
module "eks" {
  source = "tfstack/eks-basic/aws"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.28"
  vpc_id          = "vpc-12345678"
  subnet_ids      = ["subnet-12345678", "subnet-87654321"]

  compute_mode = ["ec2"]

  # Enable EKS Capabilities for platform engineering
  enable_ack_capability    = true  # AWS Controllers for Kubernetes
  enable_kro_capability    = true  # Kube Resource Orchestrator
  enable_argocd_capability = true  # ArgoCD GitOps

  tags = {
    Environment = "production"
  }
}
```

### Fargate Example

```hcl
module "eks" {
  source = "tfstack/eks-basic/aws"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.28"
  vpc_id          = "vpc-12345678"
  subnet_ids      = ["subnet-12345678", "subnet-87654321"]

  # Fargate compute mode
  compute_mode = ["fargate"]

  fargate_profiles = {
    default = {
      subnet_ids = ["subnet-12345678"]
      selectors = [
        {
          namespace = "default"
          labels    = {}
        }
      ]
    }
  }

  tags = {
    Environment = "production"
  }
}
```

### Multiple Compute Modes

```hcl
module "eks" {
  source = "tfstack/eks-basic/aws"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.28"
  vpc_id          = "vpc-12345678"
  subnet_ids      = ["subnet-12345678", "subnet-87654321"]

  # Use both EC2 and Fargate
  compute_mode = ["ec2", "fargate"]

  # EC2 configuration
  node_instance_types = ["t3.medium"]
  node_desired_size   = 2

  # Fargate configuration
  fargate_profiles = {
    default = {
      subnet_ids = ["subnet-12345678"]
      selectors = [
        {
          namespace = "default"
        }
      ]
    }
  }

  tags = {
    Environment = "production"
  }
}
```

## Examples

- **[examples/basic](examples/basic/)** - Basic EKS cluster with EC2 node groups
- **[examples/ebs-web-app](examples/ebs-web-app/)** - Web application with EBS persistent volume
- **[examples/eks-capabilities](examples/eks-capabilities/)** - Complete platform engineering example with ACK, KRO, and ArgoCD capabilities

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.13 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.30 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.28.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_addon.ebs_csi_driver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_addon.pod_identity_agent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_capability.ack](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_capability) | resource |
| [aws_eks_capability.argocd](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_capability) | resource |
| [aws_eks_capability.kro](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_capability) | resource |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_fargate_profile.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_fargate_profile) | resource |
| [aws_eks_node_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_iam_openid_connect_provider.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.ack_capability](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.argocd_capability](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.aws_lb_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ebs_csi_driver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_fargate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.kro_capability](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.aws_lb_controller_waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.ebs_csi_driver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ack_capability](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.aws_lb_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.aws_lb_controller_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_cluster_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_fargate_pod_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_nodes_cni](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_nodes_ecr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_nodes_worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.aws_load_balancer_controller](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_service_account.aws_lb_controller](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [kubernetes_storage_class.ebs_csi_default](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/storage_class) | resource |
| [aws_eks_cluster_auth.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_iam_policy_document.ack_capability_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.argocd_capability_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.aws_lb_controller_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ebs_csi_driver_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.eks_cluster_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.eks_fargate_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.eks_nodes_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.kro_capability_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [tls_certificate.eks](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ack_capability_iam_policy_arns"></a> [ack\_capability\_iam\_policy\_arns](#input\_ack\_capability\_iam\_policy\_arns) | Map of IAM policy ARNs to attach to the ACK capability role. Required for ACK to manage AWS resources (e.g., S3, DynamoDB, IAM). | `map(string)` | `{}` | no |
| <a name="input_ack_capability_role_arn"></a> [ack\_capability\_role\_arn](#input\_ack\_capability\_role\_arn) | IAM role ARN for ACK capability to create AWS resources. If not provided, AWS will create a default role. | `string` | `null` | no |
| <a name="input_argocd_capability_configuration"></a> [argocd\_capability\_configuration](#input\_argocd\_capability\_configuration) | Configuration JSON for ArgoCD capability. If not provided, a minimal configuration will be used. Full ArgoCD setup requires AWS Identity Center configuration. | `string` | `null` | no |
| <a name="input_argocd_capability_role_arn"></a> [argocd\_capability\_role\_arn](#input\_argocd\_capability\_role\_arn) | IAM role ARN for ArgoCD capability. If not provided, AWS will create a default role. | `string` | `null` | no |
| <a name="input_aws_auth_map_roles"></a> [aws\_auth\_map\_roles](#input\_aws\_auth\_map\_roles) | List of IAM roles to add to aws-auth ConfigMap for Kubernetes access | <pre>list(object({<br/>    rolearn  = string<br/>    username = string<br/>    groups   = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_aws_auth_map_users"></a> [aws\_auth\_map\_users](#input\_aws\_auth\_map\_users) | List of IAM users to add to aws-auth ConfigMap for Kubernetes access | <pre>list(object({<br/>    userarn  = string<br/>    username = string<br/>    groups   = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_aws_lb_controller_helm_values"></a> [aws\_lb\_controller\_helm\_values](#input\_aws\_lb\_controller\_helm\_values) | Additional Helm values for the AWS Load Balancer Controller | `map(string)` | `{}` | no |
| <a name="input_aws_lb_controller_helm_version"></a> [aws\_lb\_controller\_helm\_version](#input\_aws\_lb\_controller\_helm\_version) | Version of the AWS Load Balancer Controller Helm chart | `string` | `"1.7.2"` | no |
| <a name="input_cluster_authentication_mode"></a> [cluster\_authentication\_mode](#input\_cluster\_authentication\_mode) | Authentication mode for the EKS cluster. Valid values: CONFIG\_MAP, API, API\_AND\_CONFIG\_MAP. Defaults to API\_AND\_CONFIG\_MAP when capabilities are enabled, otherwise CONFIG\_MAP. | `string` | `"CONFIG_MAP"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS cluster | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Kubernetes version to use for the EKS cluster | `string` | n/a | yes |
| <a name="input_compute_mode"></a> [compute\_mode](#input\_compute\_mode) | List of compute modes to enable. Valid values: ec2, fargate, automode | `list(string)` | <pre>[<br/>  "ec2"<br/>]</pre> | no |
| <a name="input_ebs_csi_driver_version"></a> [ebs\_csi\_driver\_version](#input\_ebs\_csi\_driver\_version) | Version of the AWS EBS CSI Driver add-on. If null, uses latest version. | `string` | `null` | no |
| <a name="input_enable_ack_capability"></a> [enable\_ack\_capability](#input\_enable\_ack\_capability) | Whether to enable AWS Controllers for Kubernetes (ACK) capability | `bool` | `false` | no |
| <a name="input_enable_argocd_capability"></a> [enable\_argocd\_capability](#input\_enable\_argocd\_capability) | Whether to enable ArgoCD GitOps capability | `bool` | `false` | no |
| <a name="input_enable_aws_lb_controller"></a> [enable\_aws\_lb\_controller](#input\_enable\_aws\_lb\_controller) | Whether to install AWS Load Balancer Controller | `bool` | `false` | no |
| <a name="input_enable_ebs_csi_driver"></a> [enable\_ebs\_csi\_driver](#input\_enable\_ebs\_csi\_driver) | Whether to install AWS EBS CSI Driver | `bool` | `false` | no |
| <a name="input_enable_kro_capability"></a> [enable\_kro\_capability](#input\_enable\_kro\_capability) | Whether to enable Kube Resource Orchestrator (KRO) capability | `bool` | `false` | no |
| <a name="input_enable_pod_identity_agent"></a> [enable\_pod\_identity\_agent](#input\_enable\_pod\_identity\_agent) | Whether to install EKS Pod Identity Agent add-on | `bool` | `false` | no |
| <a name="input_enabled_cluster_log_types"></a> [enabled\_cluster\_log\_types](#input\_enabled\_cluster\_log\_types) | List of control plane logging types to enable | `list(string)` | <pre>[<br/>  "api",<br/>  "audit",<br/>  "authenticator",<br/>  "controllerManager",<br/>  "scheduler"<br/>]</pre> | no |
| <a name="input_endpoint_public_access"></a> [endpoint\_public\_access](#input\_endpoint\_public\_access) | Whether the Amazon EKS public API server endpoint is enabled | `bool` | `true` | no |
| <a name="input_fargate_profiles"></a> [fargate\_profiles](#input\_fargate\_profiles) | Map of Fargate profiles to create. Key is the profile name. | <pre>map(object({<br/>    subnet_ids = optional(list(string))<br/>    selectors = optional(list(object({<br/>      namespace = string<br/>      labels    = optional(map(string))<br/>    })), [])<br/>    tags = optional(map(string))<br/>  }))</pre> | `{}` | no |
| <a name="input_kro_capability_role_arn"></a> [kro\_capability\_role\_arn](#input\_kro\_capability\_role\_arn) | IAM role ARN for KRO capability. If not provided, AWS will create a default role. | `string` | `null` | no |
| <a name="input_node_desired_size"></a> [node\_desired\_size](#input\_node\_desired\_size) | Desired number of nodes in the node group | `number` | `2` | no |
| <a name="input_node_disk_size"></a> [node\_disk\_size](#input\_node\_disk\_size) | Disk size in GiB for worker nodes | `number` | `20` | no |
| <a name="input_node_instance_types"></a> [node\_instance\_types](#input\_node\_instance\_types) | List of EC2 instance types for the node group | `list(string)` | <pre>[<br/>  "t3.medium"<br/>]</pre> | no |
| <a name="input_node_labels"></a> [node\_labels](#input\_node\_labels) | Key-value map of Kubernetes labels to apply to nodes | `map(string)` | `{}` | no |
| <a name="input_node_max_size"></a> [node\_max\_size](#input\_node\_max\_size) | Maximum number of nodes in the node group | `number` | `3` | no |
| <a name="input_node_min_size"></a> [node\_min\_size](#input\_node\_min\_size) | Minimum number of nodes in the node group | `number` | `1` | no |
| <a name="input_node_remote_access_enabled"></a> [node\_remote\_access\_enabled](#input\_node\_remote\_access\_enabled) | Whether to enable remote access to nodes | `bool` | `false` | no |
| <a name="input_node_remote_access_security_groups"></a> [node\_remote\_access\_security\_groups](#input\_node\_remote\_access\_security\_groups) | List of security group IDs for remote access | `list(string)` | `[]` | no |
| <a name="input_node_remote_access_ssh_key"></a> [node\_remote\_access\_ssh\_key](#input\_node\_remote\_access\_ssh\_key) | EC2 SSH key name for remote access | `string` | `null` | no |
| <a name="input_node_subnet_ids"></a> [node\_subnet\_ids](#input\_node\_subnet\_ids) | Subnet IDs for EKS node groups (should be private subnets only for security). If null, uses subnet\_ids. | `list(string)` | `null` | no |
| <a name="input_node_update_max_unavailable"></a> [node\_update\_max\_unavailable](#input\_node\_update\_max\_unavailable) | Maximum number of nodes unavailable during update | `number` | `1` | no |
| <a name="input_pod_identity_agent_version"></a> [pod\_identity\_agent\_version](#input\_pod\_identity\_agent\_version) | Version of the EKS Pod Identity Agent add-on. If null, uses latest version. | `string` | `null` | no |
| <a name="input_public_access_cidrs"></a> [public\_access\_cidrs](#input\_public\_access\_cidrs) | List of CIDR blocks that can access the Amazon EKS public API server endpoint | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for EKS cluster control plane (should include both public and private) | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where the cluster is deployed | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ack_capability_arn"></a> [ack\_capability\_arn](#output\_ack\_capability\_arn) | ARN of the ACK capability (when enabled) |
| <a name="output_argocd_capability_arn"></a> [argocd\_capability\_arn](#output\_argocd\_capability\_arn) | ARN of the ArgoCD capability (when enabled) |
| <a name="output_aws_lb_controller_role_arn"></a> [aws\_lb\_controller\_role\_arn](#output\_aws\_lb\_controller\_role\_arn) | IAM role ARN for AWS Load Balancer Controller (when enabled) |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN of the EKS cluster |
| <a name="output_cluster_auth_token"></a> [cluster\_auth\_token](#output\_cluster\_auth\_token) | Token to authenticate with the EKS cluster |
| <a name="output_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#output\_cluster\_ca\_certificate) | Decoded certificate data required to communicate with the cluster |
| <a name="output_cluster_ca_data"></a> [cluster\_ca\_data](#output\_cluster\_ca\_data) | Base64 encoded certificate data required to communicate with the cluster |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Endpoint for EKS control plane |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the EKS cluster |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | Kubernetes version of the EKS cluster |
| <a name="output_ebs_csi_driver_role_arn"></a> [ebs\_csi\_driver\_role\_arn](#output\_ebs\_csi\_driver\_role\_arn) | IAM role ARN for EBS CSI Driver (when enabled) |
| <a name="output_fargate_profile_arns"></a> [fargate\_profile\_arns](#output\_fargate\_profile\_arns) | Map of Fargate profile ARNs (when Fargate mode is enabled) |
| <a name="output_fargate_role_arn"></a> [fargate\_role\_arn](#output\_fargate\_role\_arn) | IAM role ARN for Fargate pods (when Fargate mode is enabled) |
| <a name="output_kro_capability_arn"></a> [kro\_capability\_arn](#output\_kro\_capability\_arn) | ARN of the KRO capability (when enabled) |
| <a name="output_node_group_arn"></a> [node\_group\_arn](#output\_node\_group\_arn) | ARN of the EKS node group (when EC2 mode is enabled) |
| <a name="output_node_group_id"></a> [node\_group\_id](#output\_node\_group\_id) | ID of the EKS node group (when EC2 mode is enabled) |
| <a name="output_node_group_status"></a> [node\_group\_status](#output\_node\_group\_status) | Status of the EKS node group (when EC2 mode is enabled) |
| <a name="output_node_role_arn"></a> [node\_role\_arn](#output\_node\_role\_arn) | IAM role ARN for EC2 nodes (when EC2 mode is enabled) |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the EKS OIDC provider |
| <a name="output_oidc_provider_url"></a> [oidc\_provider\_url](#output\_oidc\_provider\_url) | URL of the EKS OIDC provider |
<!-- END_TF_DOCS -->

## Connecting to the Cluster

After the cluster is created, configure `kubectl`:

```bash
aws eks update-kubeconfig --name <cluster_name> --region <aws_region>
```

Verify connection:

```bash
kubectl get nodes
```

## Testing

The module includes comprehensive tests using Terraform's test framework. Run tests with:

```bash
terraform test
```

## Module Structure

```plaintext
terraform-aws-eks-basic/
├── main.tf              # Core EKS cluster, IAM roles, OIDC provider
├── ec2.tf              # EC2 managed node groups
├── fargate.tf          # Fargate profiles
├── automode.tf         # AutoMode configuration
├── capabilities.tf     # EKS Capabilities (ACK, KRO, ArgoCD)
├── capabilities-iam.tf # IAM roles for EKS Capabilities
├── addons.tf           # Optional addons (EBS CSI, ALB Controller)
├── variables.tf        # Input variables
├── outputs.tf          # Output values
├── versions.tf         # Provider version constraints
├── README.md           # This file
├── tests/
│   └── eks_test.tftest.hcl  # Test suite
└── examples/
    └── basic/          # Basic usage example
```

## License

MIT License - see LICENSE file for details.
