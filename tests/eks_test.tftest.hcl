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
      # Argo CD requires configuration.argo_cd.aws_idc (validation); minimal config for plan-only test
      argocd = {
        configuration = {
          argo_cd = {
            aws_idc = {
              idc_instance_arn = "arn:aws:sso:::instance/ssoins-test"
            }
          }
        }
      }
    }
  }

  assert {
    condition     = length(aws_eks_capability.this) == 3
    error_message = "All three capabilities (ACK, KRO, Argo CD) should be created"
  }

  assert {
    condition     = length(aws_iam_role.capability) == 3
    error_message = "IAM roles for all three capabilities should be created"
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
    condition     = length(aws_iam_policy.aws_lb_controller) == 1
    error_message = "AWS Load Balancer Controller least-privilege policy should be created"
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.aws_lb_controller) == 1
    error_message = "Single policy attachment should be created for ALB controller"
  }
}

run "eks_external_dns_iam" {
  command = plan

  variables {
    name                = "test-eks-cluster"
    kubernetes_version  = "1.35"
    vpc_id              = "vpc-12345678"
    subnet_ids          = ["subnet-12345678", "subnet-87654321"]
    enable_external_dns = true
  }

  assert {
    condition     = length(aws_iam_role.external_dns) == 1
    error_message = "ExternalDNS IAM role should be created when enabled"
  }

  assert {
    condition     = length(aws_iam_role_policy.external_dns) == 1
    error_message = "ExternalDNS IAM role policy should be created"
  }
}

run "eks_ebs_csi_driver_dedicated" {
  command = plan

  variables {
    name                         = "test-eks-cluster"
    kubernetes_version           = "1.35"
    vpc_id                       = "vpc-12345678"
    subnet_ids                   = ["subnet-12345678", "subnet-87654321"]
    enable_ebs_csi_driver        = true
    ebs_csi_driver_identity_type = "pod_identity"
    addons = {
      aws-ebs-csi-driver = {
        addon_version = "v1.38.0-eksbuild.1"
      }
    }
  }

  assert {
    condition     = length(aws_iam_role.ebs_csi_driver) == 1
    error_message = "EBS CSI driver IAM role should be created when enable_ebs_csi_driver is true"
  }

  assert {
    condition     = length(aws_eks_pod_identity_association.ebs_csi_driver) == 1
    error_message = "Pod Identity association for EBS CSI driver should be created when ebs_csi_driver_identity_type is pod_identity"
  }
}

run "eks_secrets_manager_pod_identity" {
  command = plan

  variables {
    name                                 = "test-eks-cluster"
    kubernetes_version                   = "1.35"
    vpc_id                               = "vpc-12345678"
    subnet_ids                           = ["subnet-12345678", "subnet-87654321"]
    enable_secrets_manager               = true
    secrets_manager_identity_type        = "pod_identity"
    secrets_manager_associations         = [{ namespace = "my-app", service_account = "awssm-sync" }]
    secrets_manager_secret_name_prefixes = ["my-app-secrets"]
  }

  assert {
    condition     = length(aws_iam_role.secrets_manager) == 1
    error_message = "Secrets Manager IAM role should be created when enable_secrets_manager is true"
  }

  assert {
    condition     = length(aws_eks_pod_identity_association.secrets_manager) == 1
    error_message = "Pod Identity association for Secrets Manager should be created when secrets_manager_identity_type is pod_identity"
  }
}

run "eks_pod_identity" {
  command = plan

  variables {
    name                                       = "test-eks-cluster"
    kubernetes_version                         = "1.35"
    vpc_id                                     = "vpc-12345678"
    subnet_ids                                 = ["subnet-12345678", "subnet-87654321"]
    enable_aws_load_balancer_controller        = true
    aws_load_balancer_controller_identity_type = "pod_identity"
    enable_external_dns                        = true
    external_dns_identity_type                 = "pod_identity"
    addon_identity_type                        = "pod_identity"
    addons = {
      eks-pod-identity-agent = {
        before_compute = true
        addon_version  = "v1.3.10-eksbuild.2"
      }
      aws-ebs-csi-driver = {
        addon_version = "v1.38.0-eksbuild.1"
      }
    }
    addon_service_accounts = {
      "aws-ebs-csi-driver" = {
        namespace = "kube-system"
        name      = "ebs-csi-controller-sa"
      }
    }
    eks_managed_node_groups = {
      default = {
        name           = "node-group-1"
        instance_types = ["t3.medium"]
        min_size       = 1
        max_size       = 2
        desired_size   = 1
      }
    }
  }

  assert {
    condition     = length(aws_iam_role.aws_lb_controller) == 1
    error_message = "ALB controller IAM role should be created when using Pod Identity"
  }

  assert {
    condition     = length(aws_eks_pod_identity_association.aws_lb_controller) == 1
    error_message = "Pod Identity association for ALB controller should be created"
  }

  assert {
    condition     = length(aws_eks_pod_identity_association.external_dns) == 1
    error_message = "Pod Identity association for External DNS should be created"
  }

  assert {
    condition     = length(aws_eks_pod_identity_association.addon) == 1
    error_message = "Pod Identity association for EBS CSI addon should be created"
  }
}

run "eks_ipv6_configuration" {
  command = plan

  variables {
    name               = "test-eks-cluster"
    kubernetes_version = "1.35"
    vpc_id             = "vpc-12345678"
    subnet_ids         = ["subnet-12345678", "subnet-87654321"]
    cluster_ip_family  = "ipv6"
    service_ipv4_cidr  = "10.100.0.0/16"
    # service_ipv6_cidr is automatically assigned by AWS, not configurable
  }

  assert {
    condition     = aws_eks_cluster.this.kubernetes_network_config[0].ip_family == "ipv6"
    error_message = "Cluster IP family should be set to ipv6"
  }

  assert {
    condition     = length(aws_security_group_rule.node_ipv6_egress) == 1
    error_message = "IPv6 egress security group rule should be created when ip_family is ipv6"
  }
}

run "eks_automode" {
  command = plan

  variables {
    name                = "test-eks-cluster"
    kubernetes_version  = "1.29"
    vpc_id              = "vpc-12345678"
    subnet_ids          = ["subnet-12345678", "subnet-87654321"]
    enable_automode     = true
    automode_node_pools = ["system", "general-purpose"]
    # eks_managed_node_groups omitted (default {}) - mutually exclusive with enable_automode
  }

  assert {
    condition     = length(aws_iam_role.eks_automode_nodes) == 1
    error_message = "Auto Mode node IAM role should be created when enable_automode is true"
  }

  # Access entry and policy association for the node role are created by EKS when using built-in node pools; we do not create them in Terraform.

  assert {
    condition     = length(aws_iam_role_policy_attachment.automode_cluster) == 4
    error_message = "Cluster role should have 4 Auto Mode policy attachments when enable_automode is true"
  }

  assert {
    condition     = aws_eks_cluster.this.storage_config[0].block_storage[0].enabled == true
    error_message = "Cluster storage_config.block_storage should be enabled when enable_automode is true"
  }

  assert {
    condition     = aws_eks_cluster.this.kubernetes_network_config[0].elastic_load_balancing[0].enabled == true
    error_message = "Cluster elastic_load_balancing should be enabled when enable_automode is true"
  }

  assert {
    condition     = length(aws_eks_cluster.this.compute_config) == 1
    error_message = "Cluster compute_config block should be present when enable_automode is true"
  }

  assert {
    condition     = length(aws_eks_node_group.this) == 0
    error_message = "No managed node groups should be created when using Auto Mode"
  }

  assert {
    condition     = length(aws_iam_role.eks_nodes) == 0
    error_message = "EC2 node IAM role should not be created when using Auto Mode (no managed node groups)"
  }
}

run "eks_fargate_profiles" {
  command = plan

  variables {
    name               = "test-eks-fargate"
    kubernetes_version = "1.35"
    vpc_id             = "vpc-12345678"
    subnet_ids         = ["subnet-private-a", "subnet-private-b"]
    fargate_profiles = {
      kube-system = {
        selectors = [{ namespace = "kube-system" }]
      }
    }
  }

  assert {
    condition     = length(aws_iam_role.eks_fargate) == 1
    error_message = "Fargate pod execution IAM role should be created when fargate_profiles is set and create_fargate_pod_execution_role is true"
  }

  assert {
    condition     = length(aws_eks_fargate_profile.this) == 1
    error_message = "One Fargate profile should be created for kube-system"
  }

  assert {
    condition     = length(aws_eks_access_entry.fargate) == 1
    error_message = "Fargate access entry should exist for API_AND_CONFIG_MAP default auth"
  }
}

run "eks_fargate_byo_execution_role" {
  command = plan

  variables {
    name                              = "test-eks-fargate-byo"
    kubernetes_version                = "1.35"
    vpc_id                            = "vpc-12345678"
    subnet_ids                        = ["subnet-private-a", "subnet-private-b"]
    create_fargate_pod_execution_role = false
    fargate_pod_execution_role_arn    = "arn:aws:iam::123456789012:role/existing-fargate-pod-exec"
    fargate_profiles = {
      app = {
        selectors = [{ namespace = "app" }]
      }
    }
  }

  assert {
    condition     = length(aws_iam_role.eks_fargate) == 0
    error_message = "Module should not create Fargate execution role when create_fargate_pod_execution_role is false"
  }

  assert {
    condition     = aws_eks_fargate_profile.this["app"].pod_execution_role_arn == "arn:aws:iam::123456789012:role/existing-fargate-pod-exec"
    error_message = "Fargate profile should use the supplied pod execution role ARN"
  }

  assert {
    condition     = length(aws_eks_access_entry.fargate) == 1
    error_message = "Fargate access entry should still be created for the supplied execution role ARN"
  }
}

run "eks_fargate_skip_access_entry" {
  command = plan

  variables {
    name                        = "test-eks-fargate-no-ae"
    kubernetes_version          = "1.35"
    vpc_id                      = "vpc-12345678"
    subnet_ids                  = ["subnet-private-a", "subnet-private-b"]
    create_fargate_access_entry = false
    fargate_profiles = {
      app = {
        selectors = [{ namespace = "app" }]
      }
    }
  }

  assert {
    condition     = length(aws_eks_access_entry.fargate) == 0
    error_message = "No Fargate access entry when create_fargate_access_entry is false"
  }

  assert {
    condition     = length(aws_iam_role.eks_fargate) == 1
    error_message = "Pod execution role still created when only access entry is skipped"
  }
}
