# terraform-aws-eks-basic

> **⚠️ Note**: This module has been revamped and currently supports **EC2 managed node groups only**. Fargate and AutoMode support are not available in this version.

A Terraform module for creating and managing Amazon EKS (Elastic Kubernetes Service) clusters with EC2 managed node groups.

## Features

- **EC2 Managed Node Groups**: Full support with customizable launch templates and auto-scaling
- **Dual-Stack Support**: IPv4 and IPv6 cluster support (IPv6 service CIDR auto-assigned by AWS)
- **Modern EKS Access Entries**: Native EKS authentication via access entries (no aws-auth ConfigMap)
- **IRSA Support**: OIDC provider setup for IAM Roles for Service Accounts
- **EKS Addons**: Flexible addon configuration (CoreDNS, VPC CNI, Kube-proxy, Pod Identity Agent, EBS CSI Driver)
- **EKS Capabilities**: Support for ACK, KRO, and ArgoCD capabilities
- **AWS Load Balancer Controller**: Optional IAM role creation for AWS Load Balancer Controller (IRSA)
- **Security**: KMS encryption, IMDSv2 enforcement, security groups
- **CloudWatch Log Group**: Optional log group for EKS control plane logs; set `cloudwatch_log_group_force_destroy = true` to allow the log group to be deleted on `terraform destroy` (default is to protect it).

## Prerequisites

| Name | Version |
| ---- | ------- |
| terraform | >= 1.6.0 |
| aws | >= 6.0 |
| kubernetes | ~> 2.30 |
| helm | ~> 2.13 |
| tls | ~> 4.0 |

## Usage

### Basic Example

```hcl
module "eks" {
  source = "tfstack/eks-basic/aws"

  name               = "my-eks-cluster"
  kubernetes_version = "1.35"
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-12345678", "subnet-87654321"]

  endpoint_public_access = true

  # Configure access entries for cluster access
  access_entries = {
    admin = {
      principal_arn = "arn:aws:iam::123456789012:role/admin-role"
      type          = "STANDARD"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Configure EKS addons
  addons = {
    coredns = {
      addon_version = "v1.13.2-eksbuild.1"
    }
    kube-proxy = {
      addon_version = "v1.35.0-eksbuild.2"
    }
    vpc-cni = {
      before_compute = true
      addon_version  = "v1.21.1-eksbuild.3"
    }
    eks-pod-identity-agent = {
      before_compute = true
      addon_version  = "v1.3.10-eksbuild.2"
    }
  }

  # Configure managed node groups
  eks_managed_node_groups = {
    default = {
      name           = "node-group-1"
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      disk_size      = 20
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

## Examples

- **[examples/basic](examples/basic/)** - Basic EKS cluster with EC2 node groups
- **[examples/ebs-web-app](examples/ebs-web-app/)** - EKS cluster with node groups and VPC setup
- **[examples/eks-capabilities](examples/eks-capabilities/)** - Platform engineering example with EKS capabilities

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.13 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.30 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.28.0 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.13.1 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.this_allow_destroy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.this_prevent_destroy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eks_access_entry.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_policy_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) | resource |
| [aws_eks_addon.before_compute](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_addon.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_capability.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_capability) | resource |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_iam_instance_profile.eks_nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_openid_connect_provider.oidc_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_policy.cluster_encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.addon](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.aws_lb_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.capability](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.external_dns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.aws_lb_controller_waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.external_dns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.aws_lb_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.capability](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.cluster_encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ebs_csi_driver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_launch_template.node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_security_group.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.node_cidr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.node_ipv6_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.node_self](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.node_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [time_sleep.this](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster_auth.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_iam_policy_document.addon_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.aws_lb_controller_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.aws_lb_controller_waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.capability_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.eks_cluster_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.eks_nodes_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.external_dns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.external_dns_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.kms_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [tls_certificate.this](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_entries"></a> [access\_entries](#input\_access\_entries) | Map of access entries to add to the cluster | <pre>map(object({<br/>    # Access entry<br/>    kubernetes_groups = optional(list(string))<br/>    principal_arn     = string<br/>    type              = optional(string, "STANDARD")<br/>    user_name         = optional(string)<br/>    tags              = optional(map(string), {})<br/>    # Access policy association<br/>    policy_associations = optional(map(object({<br/>      policy_arn = string<br/>      access_scope = object({<br/>        namespaces = optional(list(string))<br/>        type       = string<br/>      })<br/>    })), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_addons"></a> [addons](#input\_addons) | Map of EKS addons to enable | <pre>map(object({<br/>    addon_version               = optional(string)<br/>    before_compute              = optional(bool, false)<br/>    configuration_values        = optional(string)<br/>    resolve_conflicts_on_create = optional(string, "OVERWRITE")<br/>    resolve_conflicts_on_update = optional(string, "OVERWRITE")<br/>    service_account_role_arn    = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_capabilities"></a> [capabilities](#input\_capabilities) | Map of EKS capabilities to enable. Valid keys: ack, kro, argocd | <pre>map(object({<br/>    role_arn                  = optional(string)<br/>    iam_policy_arns           = optional(map(string), {})<br/>    configuration             = optional(string)<br/>    delete_propagation_policy = optional(string, "RETAIN")<br/>  }))</pre> | `{}` | no |
| <a name="input_cloudwatch_log_group_class"></a> [cloudwatch\_log\_group\_class](#input\_cloudwatch\_log\_group\_class) | Specifies the log class of the log group. Valid values are: STANDARD or INFREQUENT\_ACCESS | `string` | `null` | no |
| <a name="input_cloudwatch_log_group_force_destroy"></a> [cloudwatch\_log\_group\_force\_destroy](#input\_cloudwatch\_log\_group\_force\_destroy) | When true, allow the CloudWatch log group to be deleted on terraform destroy. When false, protect it with lifecycle { prevent\_destroy = true }. | `bool` | `false` | no |
| <a name="input_cloudwatch_log_group_kms_key_id"></a> [cloudwatch\_log\_group\_kms\_key\_id](#input\_cloudwatch\_log\_group\_kms\_key\_id) | The ARN of the KMS Key to use when encrypting log data | `string` | `null` | no |
| <a name="input_cloudwatch_log_group_retention_in_days"></a> [cloudwatch\_log\_group\_retention\_in\_days](#input\_cloudwatch\_log\_group\_retention\_in\_days) | Number of days to retain log events in the CloudWatch log group | `number` | `14` | no |
| <a name="input_cloudwatch_log_group_tags"></a> [cloudwatch\_log\_group\_tags](#input\_cloudwatch\_log\_group\_tags) | Additional tags to apply to the CloudWatch log group | `map(string)` | `{}` | no |
| <a name="input_cluster_authentication_mode"></a> [cluster\_authentication\_mode](#input\_cluster\_authentication\_mode) | Authentication mode for the EKS cluster. Valid values: CONFIG\_MAP, API, API\_AND\_CONFIG\_MAP. Defaults to API\_AND\_CONFIG\_MAP when capabilities are enabled, otherwise CONFIG\_MAP. | `string` | `"API_AND_CONFIG_MAP"` | no |
| <a name="input_cluster_encryption_config_key_arn"></a> [cluster\_encryption\_config\_key\_arn](#input\_cluster\_encryption\_config\_key\_arn) | ARN of the KMS key to use for encrypting Kubernetes secrets | `string` | `null` | no |
| <a name="input_cluster_encryption_config_resources"></a> [cluster\_encryption\_config\_resources](#input\_cluster\_encryption\_config\_resources) | List of strings with resources to be encrypted. Valid values: secrets | `list(string)` | <pre>[<br/>  "secrets"<br/>]</pre> | no |
| <a name="input_cluster_ip_family"></a> [cluster\_ip\_family](#input\_cluster\_ip\_family) | IP family for the EKS cluster. Valid values: ipv4, ipv6 | `string` | `"ipv4"` | no |
| <a name="input_create_cloudwatch_log_group"></a> [create\_cloudwatch\_log\_group](#input\_create\_cloudwatch\_log\_group) | Whether to create a CloudWatch log group for EKS cluster logs | `bool` | `true` | no |
| <a name="input_create_kms_key"></a> [create\_kms\_key](#input\_create\_kms\_key) | Controls if a KMS key for cluster encryption should be created | `bool` | `true` | no |
| <a name="input_eks_managed_node_groups"></a> [eks\_managed\_node\_groups](#input\_eks\_managed\_node\_groups) | Map of EKS managed node group configurations | <pre>map(object({<br/>    name                       = optional(string)<br/>    ami_type                   = optional(string, "AL2023_x86_64_STANDARD")<br/>    instance_types             = optional(list(string), ["t3.medium"])<br/>    min_size                   = optional(number, 1)<br/>    max_size                   = optional(number, 3)<br/>    desired_size               = optional(number, 2)<br/>    disk_size                  = optional(number, 20)<br/>    subnet_ids                 = optional(list(string))<br/>    enable_bootstrap_user_data = optional(bool, true)<br/>    metadata_options = optional(object({<br/>      http_endpoint               = optional(string, "enabled")<br/>      http_tokens                 = optional(string, "required")<br/>      http_put_response_hop_limit = optional(number, 1)<br/>    }))<br/>    labels = optional(map(string), {})<br/>    tags   = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_enable_aws_load_balancer_controller"></a> [enable\_aws\_load\_balancer\_controller](#input\_enable\_aws\_load\_balancer\_controller) | Whether to create IAM role for AWS Load Balancer Controller (IRSA) | `bool` | `false` | no |
| <a name="input_enable_cluster_creator_admin_permissions"></a> [enable\_cluster\_creator\_admin\_permissions](#input\_enable\_cluster\_creator\_admin\_permissions) | Indicates whether or not to add the cluster creator (the identity used by Terraform) as an administrator via access entry | `bool` | `false` | no |
| <a name="input_enable_external_dns"></a> [enable\_external\_dns](#input\_enable\_external\_dns) | Whether to create IAM role for ExternalDNS (IRSA) | `bool` | `false` | no |
| <a name="input_enabled_cluster_log_types"></a> [enabled\_cluster\_log\_types](#input\_enabled\_cluster\_log\_types) | List of control plane logging types to enable | `list(string)` | <pre>[<br/>  "api",<br/>  "audit",<br/>  "authenticator"<br/>]</pre> | no |
| <a name="input_endpoint_public_access"></a> [endpoint\_public\_access](#input\_endpoint\_public\_access) | Whether the Amazon EKS public API server endpoint is enabled | `bool` | `true` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version to use for the EKS cluster | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the EKS cluster | `string` | n/a | yes |
| <a name="input_public_access_cidrs"></a> [public\_access\_cidrs](#input\_public\_access\_cidrs) | List of CIDR blocks that can access the Amazon EKS public API server endpoint | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region for CloudWatch log group | `string` | `"ap-southeast-2"` | no |
| <a name="input_service_ipv4_cidr"></a> [service\_ipv4\_cidr](#input\_service\_ipv4\_cidr) | IPv4 CIDR block for Kubernetes services. Required for all clusters. Must not overlap with VPC CIDR. If not provided, EKS will auto-assign. | `string` | `null` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for EKS cluster control plane (should include both public and private) | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where the cluster is deployed | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_entries"></a> [access\_entries](#output\_access\_entries) | Map of access entries created and their attributes |
| <a name="output_access_policy_associations"></a> [access\_policy\_associations](#output\_access\_policy\_associations) | Map of eks cluster access policy associations created and their attributes |
| <a name="output_aws_load_balancer_controller_role_arn"></a> [aws\_load\_balancer\_controller\_role\_arn](#output\_aws\_load\_balancer\_controller\_role\_arn) | IAM role ARN for AWS Load Balancer Controller (when enabled) |
| <a name="output_cloudwatch_log_group_arn"></a> [cloudwatch\_log\_group\_arn](#output\_cloudwatch\_log\_group\_arn) | Arn of cloudwatch log group created |
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | Name of cloudwatch log group created |
| <a name="output_cluster_addons"></a> [cluster\_addons](#output\_cluster\_addons) | Map of attribute maps for all EKS cluster addons enabled |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | The Amazon Resource Name (ARN) of the cluster |
| <a name="output_cluster_auth_token"></a> [cluster\_auth\_token](#output\_cluster\_auth\_token) | Token to authenticate with the EKS cluster |
| <a name="output_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#output\_cluster\_ca\_certificate) | Decoded certificate data required to communicate with the cluster |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64 encoded certificate data required to communicate with the cluster |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Endpoint for your Kubernetes API server |
| <a name="output_cluster_iam_role_arn"></a> [cluster\_iam\_role\_arn](#output\_cluster\_iam\_role\_arn) | Cluster IAM role ARN |
| <a name="output_cluster_iam_role_name"></a> [cluster\_iam\_role\_name](#output\_cluster\_iam\_role\_name) | Cluster IAM role name |
| <a name="output_cluster_ip_family"></a> [cluster\_ip\_family](#output\_cluster\_ip\_family) | The IP family used by the cluster (e.g. ipv4 or ipv6) |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the EKS cluster |
| <a name="output_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#output\_cluster\_oidc\_issuer\_url) | The URL on the EKS cluster for the OpenID Connect identity provider |
| <a name="output_cluster_platform_version"></a> [cluster\_platform\_version](#output\_cluster\_platform\_version) | Platform version for the cluster |
| <a name="output_cluster_primary_security_group_id"></a> [cluster\_primary\_security\_group\_id](#output\_cluster\_primary\_security\_group\_id) | Cluster security group that was created by Amazon EKS for the cluster |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | ID of the cluster security group |
| <a name="output_cluster_service_cidr"></a> [cluster\_service\_cidr](#output\_cluster\_service\_cidr) | The IPv4 CIDR block where Kubernetes pod and service IP addresses are assigned from |
| <a name="output_cluster_service_ipv6_cidr"></a> [cluster\_service\_ipv6\_cidr](#output\_cluster\_service\_ipv6\_cidr) | The IPv6 CIDR block where Kubernetes pod and service IP addresses are assigned from (when ip\_family is ipv6) |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | The Kubernetes version for the cluster |
| <a name="output_eks_managed_node_groups"></a> [eks\_managed\_node\_groups](#output\_eks\_managed\_node\_groups) | Map of attribute maps for all EKS managed node groups created |
| <a name="output_external_dns_role_arn"></a> [external\_dns\_role\_arn](#output\_external\_dns\_role\_arn) | IAM role ARN for ExternalDNS (when enabled) |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | The Amazon Resource Name (ARN) of the key |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | The globally unique identifier for the key |
| <a name="output_launch_templates"></a> [launch\_templates](#output\_launch\_templates) | Map of launch templates created for node groups |
| <a name="output_node_iam_role_arn"></a> [node\_iam\_role\_arn](#output\_node\_iam\_role\_arn) | Node IAM role ARN |
| <a name="output_node_iam_role_name"></a> [node\_iam\_role\_name](#output\_node\_iam\_role\_name) | Node IAM role name |
| <a name="output_node_security_group_id"></a> [node\_security\_group\_id](#output\_node\_security\_group\_id) | ID of the node shared security group |
| <a name="output_oidc_provider"></a> [oidc\_provider](#output\_oidc\_provider) | The OpenID Connect identity provider (issuer URL without leading `https://`) |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | The ARN of the OIDC Provider |
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
├── main.tf              # Core EKS cluster, node groups, addons, OIDC provider
├── access-entries.tf    # EKS access entries for authentication
├── capabilities.tf      # EKS Capabilities (ACK, KRO, ArgoCD)
├── capabilities-iam.tf  # IAM roles for EKS Capabilities
├── addons-iam.tf        # IAM roles for addons (EBS CSI, etc)
├── locals.tf            # Local values and computed configurations
├── cluster-auth.tf      # Cluster authentication data source
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── versions.tf          # Provider version constraints
├── README.md            # This file
└── examples/
    ├── basic/           # Basic usage example
    ├── ebs-web-app/     # Example with VPC and node groups
    └── eks-capabilities/ # Platform engineering with capabilities
```

## License

MIT License - see LICENSE file for details.
