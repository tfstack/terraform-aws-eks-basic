run "eks_cluster_creation" {
  command = plan

  variables {
    cluster_name    = "test-eks-cluster"
    cluster_version = "1.28"
    vpc_id          = "vpc-12345678"
    subnet_ids      = ["subnet-12345678", "subnet-87654321"]
    compute_mode    = ["ec2"]
  }

  assert {
    condition     = aws_eks_cluster.this.name == "test-eks-cluster"
    error_message = "EKS cluster name should be 'test-eks-cluster'"
  }

  assert {
    condition     = aws_eks_cluster.this.version == "1.28"
    error_message = "EKS cluster version should be '1.28'"
  }

  assert {
    condition     = length(aws_eks_cluster.this.vpc_config[0].subnet_ids) == 2
    error_message = "EKS cluster should have 2 subnet IDs"
  }
}

run "eks_node_group_config" {
  command = plan

  variables {
    cluster_name        = "test-eks-cluster"
    cluster_version     = "1.28"
    vpc_id              = "vpc-12345678"
    subnet_ids          = ["subnet-12345678", "subnet-87654321"]
    compute_mode        = ["ec2"]
    node_instance_types = ["t3.medium", "t3.large"]
    node_desired_size   = 3
    node_min_size       = 2
    node_max_size       = 5
    node_disk_size      = 50
  }

  assert {
    condition     = length(aws_eks_node_group.default) == 1
    error_message = "Node group should be created when EC2 mode is enabled"
  }

  assert {
    condition     = aws_eks_node_group.default[0].scaling_config[0].desired_size == 3
    error_message = "Node group desired size should be 3"
  }

  assert {
    condition     = aws_eks_node_group.default[0].scaling_config[0].min_size == 2
    error_message = "Node group min size should be 2"
  }

  assert {
    condition     = aws_eks_node_group.default[0].scaling_config[0].max_size == 5
    error_message = "Node group max size should be 5"
  }

  assert {
    condition     = aws_eks_node_group.default[0].disk_size == 50
    error_message = "Node group disk size should be 50"
  }
}

run "eks_iam_roles" {
  command = plan

  variables {
    cluster_name    = "test-eks-cluster"
    cluster_version = "1.28"
    vpc_id          = "vpc-12345678"
    subnet_ids      = ["subnet-12345678", "subnet-87654321"]
    compute_mode    = ["ec2"]
  }

  assert {
    condition     = aws_iam_role.eks_cluster.name == "test-eks-cluster-eks-cluster-role"
    error_message = "Cluster IAM role name should be correct"
  }

  assert {
    condition     = length(aws_iam_role.eks_nodes) == 1
    error_message = "Node IAM role should be created when EC2 mode is enabled"
  }

  assert {
    condition     = aws_iam_role.eks_nodes[0].name == "test-eks-cluster-eks-nodes-role"
    error_message = "Node IAM role name should be correct"
  }
}

run "eks_oidc_provider" {
  command = plan

  variables {
    cluster_name    = "test-eks-cluster"
    cluster_version = "1.28"
    vpc_id          = "vpc-12345678"
    subnet_ids      = ["subnet-12345678", "subnet-87654321"]
    compute_mode    = ["ec2"]
  }

  assert {
    condition     = contains(aws_iam_openid_connect_provider.eks.client_id_list, "sts.amazonaws.com")
    error_message = "OIDC provider client ID should include 'sts.amazonaws.com'"
  }
}

run "eks_addons_optional" {
  command = plan

  variables {
    cluster_name             = "test-eks-cluster"
    cluster_version          = "1.28"
    vpc_id                   = "vpc-12345678"
    subnet_ids               = ["subnet-12345678", "subnet-87654321"]
    compute_mode             = ["ec2"]
    enable_ebs_csi_driver    = true
    enable_aws_lb_controller = true
  }

  assert {
    condition     = length(aws_iam_role.ebs_csi_driver) == 1
    error_message = "EBS CSI Driver IAM role should be created when enabled"
  }

  assert {
    condition     = length(aws_eks_addon.ebs_csi_driver) == 1
    error_message = "EBS CSI Driver addon should be created when enabled"
  }

  assert {
    condition     = length(aws_iam_role.aws_lb_controller) == 1
    error_message = "AWS Load Balancer Controller IAM role should be created when enabled"
  }

  assert {
    condition     = length(kubernetes_service_account.aws_lb_controller) == 1
    error_message = "AWS Load Balancer Controller service account should be created when enabled"
  }
}

run "eks_fargate_mode" {
  command = plan

  variables {
    cluster_name    = "test-eks-cluster"
    cluster_version = "1.28"
    vpc_id          = "vpc-12345678"
    subnet_ids      = ["subnet-12345678", "subnet-87654321"]
    compute_mode    = ["fargate"]
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
  }

  assert {
    condition     = length(aws_iam_role.eks_fargate) == 1
    error_message = "Fargate IAM role should be created when Fargate mode is enabled"
  }

  assert {
    condition     = length(aws_eks_fargate_profile.default) == 1
    error_message = "Fargate profile should be created when Fargate mode is enabled"
  }
}
