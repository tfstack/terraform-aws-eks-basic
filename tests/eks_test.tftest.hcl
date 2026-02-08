run "eks_cluster_creation" {
  command = plan

  variables {
    name               = "test-eks-cluster"
    kubernetes_version = "1.35"
    vpc_id             = "vpc-12345678"
    subnet_ids         = ["subnet-12345678", "subnet-87654321"]
  }

  assert {
    condition     = aws_eks_cluster.this.name == "test-eks-cluster"
    error_message = "EKS cluster name should be 'test-eks-cluster'"
  }

  assert {
    condition     = aws_eks_cluster.this.version == "1.35"
    error_message = "EKS cluster version should be '1.35'"
  }

  assert {
    condition     = length(aws_eks_cluster.this.vpc_config[0].subnet_ids) == 2
    error_message = "EKS cluster should have 2 subnet IDs"
  }
}

run "eks_node_group_config" {
  command = plan

  variables {
    name               = "test-eks-cluster"
    kubernetes_version = "1.35"
    vpc_id             = "vpc-12345678"
    subnet_ids         = ["subnet-12345678", "subnet-87654321"]
    eks_managed_node_groups = {
      test = {
        name           = "test-node-group"
        ami_type       = "AL2023_x86_64_STANDARD"
        instance_types = ["t3.medium", "t3.large"]
        min_size       = 2
        max_size       = 5
        desired_size   = 3
        disk_size      = 50
        subnet_ids     = ["subnet-12345678", "subnet-87654321"]
      }
    }
  }

  assert {
    condition     = length(aws_eks_node_group.this) == 1
    error_message = "Node group should be created when eks_managed_node_groups is configured"
  }

  assert {
    condition     = aws_eks_node_group.this["test"].scaling_config[0].desired_size == 3
    error_message = "Node group desired size should be 3"
  }

  assert {
    condition     = aws_eks_node_group.this["test"].scaling_config[0].min_size == 2
    error_message = "Node group min size should be 2"
  }

  assert {
    condition     = aws_eks_node_group.this["test"].scaling_config[0].max_size == 5
    error_message = "Node group max size should be 5"
  }

  assert {
    condition     = length(aws_launch_template.node_group) == 1
    error_message = "Launch template should be created for node group"
  }
}

run "eks_iam_roles" {
  command = plan

  variables {
    name               = "test-eks-cluster"
    kubernetes_version = "1.35"
    vpc_id             = "vpc-12345678"
    subnet_ids         = ["subnet-12345678", "subnet-87654321"]
    eks_managed_node_groups = {
      test = {
        name           = "test-node-group"
        ami_type       = "AL2023_x86_64_STANDARD"
        instance_types = ["t3.medium"]
        subnet_ids     = ["subnet-12345678"]
      }
    }
  }

  assert {
    condition     = length(aws_iam_role.this) == 1
    error_message = "Cluster IAM role should be created"
  }

  assert {
    condition     = length(aws_iam_role.eks_nodes) == 1
    error_message = "Node IAM role should be created when eks_managed_node_groups is configured"
  }
}

run "eks_oidc_provider" {
  command = plan

  variables {
    name               = "test-eks-cluster"
    kubernetes_version = "1.35"
    vpc_id             = "vpc-12345678"
    subnet_ids         = ["subnet-12345678", "subnet-87654321"]
  }

  assert {
    condition     = contains(aws_iam_openid_connect_provider.oidc_provider[0].client_id_list, "sts.amazonaws.com")
    error_message = "OIDC provider client ID should include 'sts.amazonaws.com'"
  }
}

run "eks_addons" {
  command = plan

  variables {
    name               = "test-eks-cluster"
    kubernetes_version = "1.35"
    vpc_id             = "vpc-12345678"
    subnet_ids         = ["subnet-12345678", "subnet-87654321"]
    addons = {
      coredns = {
        addon_version = "v1.13.2-eksbuild.1"
      }
      vpc-cni = {
        before_compute = true
        addon_version  = "v1.21.1-eksbuild.3"
      }
    }
  }

  assert {
    condition     = length(aws_eks_addon.this) == 1
    error_message = "CoreDNS addon should be created"
  }

  assert {
    condition     = length(aws_eks_addon.before_compute) == 1
    error_message = "VPC CNI addon should be created as before_compute"
  }
}

run "eks_access_entries" {
  command = plan

  variables {
    name               = "test-eks-cluster"
    kubernetes_version = "1.35"
    vpc_id             = "vpc-12345678"
    subnet_ids         = ["subnet-12345678", "subnet-87654321"]
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
  }

  assert {
    condition     = length(aws_eks_access_entry.this) == 1
    error_message = "Access entry should be created when access_entries is configured"
  }

  assert {
    condition     = length(aws_eks_access_policy_association.this) == 1
    error_message = "Access policy association should be created"
  }
}

run "eks_capabilities" {
  command = plan

  variables {
    name               = "test-eks-cluster"
    kubernetes_version = "1.35"
    vpc_id             = "vpc-12345678"
    subnet_ids         = ["subnet-12345678", "subnet-87654321"]
    capabilities = {
      ack = {
        iam_policy_arns = {
          s3 = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
        }
      }
      kro = {}
    }
  }

  assert {
    condition     = length(aws_eks_capability.this) == 2
    error_message = "Two capabilities (ACK and KRO) should be created"
  }

  assert {
    condition     = length(aws_iam_role.capability) == 2
    error_message = "IAM roles for capabilities should be created"
  }
}

run "eks_aws_lb_controller_iam" {
  command = plan

  variables {
    name                                = "test-eks-cluster"
    kubernetes_version                  = "1.35"
    vpc_id                              = "vpc-12345678"
    subnet_ids                          = ["subnet-12345678", "subnet-87654321"]
    enable_aws_load_balancer_controller = true
  }

  assert {
    condition     = length(aws_iam_role.aws_lb_controller) == 1
    error_message = "AWS Load Balancer Controller IAM role should be created when enabled"
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.aws_lb_controller) == 2
    error_message = "Two policy attachments should be created (ELB and EC2)"
  }
}
