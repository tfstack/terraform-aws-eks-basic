# terraform-aws-eks-basic

A basic Terraform module for creating and managing Amazon EKS (Elastic Kubernetes Service) clusters. This module supports multiple compute modes: EC2, Fargate, and AutoMode, with EC2 as the primary focus.

## Features

- **Multi-Compute Support**: Supports EC2, Fargate, and AutoMode compute types
- **EC2 Managed Node Groups**: Full support for EC2 managed node groups with auto-scaling
- **Fargate Profiles**: Structure ready for Fargate profile configuration
- **AutoMode**: Structure ready for EKS AutoMode configuration
- **IRSA Support**: OIDC provider setup for IAM Roles for Service Accounts
- **EKS Capabilities**: Managed ACK, KRO, and ArgoCD capabilities (optional, default: disabled)
  - **ACK**: AWS Controllers for Kubernetes - create AWS resources via Kubernetes manifests
  - **KRO**: Kube Resource Orchestrator - platform engineering abstractions
  - **ArgoCD**: GitOps capability for continuous deployment
- **Optional Addons**:
  - EBS CSI Driver (optional, default: disabled)
  - AWS Load Balancer Controller (optional, default: disabled)
- **Comprehensive Testing**: Includes Terraform test suite

## Requirements

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
  source = "path/to/terraform-aws-eks-basic"

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
  source = "path/to/terraform-aws-eks-basic"

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
  source = "path/to/terraform-aws-eks-basic"

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
  source = "path/to/terraform-aws-eks-basic"

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
  source = "path/to/terraform-aws-eks-basic"

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
