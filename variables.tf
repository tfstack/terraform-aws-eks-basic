################################################################################
# Core Cluster Configuration
################################################################################

variable "name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}

################################################################################
# Network Configuration
################################################################################

variable "vpc_id" {
  description = "VPC ID where the cluster is deployed"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EKS cluster control plane (should include both public and private)"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Whether the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "private_access_cidrs" {
  description = "List of CIDR blocks that can access the Amazon EKS private API server endpoint"
  type        = list(string)
  default     = []
}

variable "cluster_ip_family" {
  description = "IP family for the EKS cluster. Valid values: ipv4, ipv6"
  type        = string
  default     = "ipv4"

  validation {
    condition     = contains(["ipv4", "ipv6"], var.cluster_ip_family)
    error_message = "cluster_ip_family must be either 'ipv4' or 'ipv6'"
  }
}

variable "service_ipv4_cidr" {
  description = "IPv4 CIDR block for Kubernetes services. Required for all clusters. Must not overlap with VPC CIDR. If not provided, EKS will auto-assign."
  type        = string
  default     = null
}

################################################################################
# Logging Configuration
################################################################################

variable "enabled_cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "create_cloudwatch_log_group" {
  description = "Whether to create a CloudWatch log group for EKS cluster logs"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "Number of days to retain log events in the CloudWatch log group"
  type        = number
  default     = 14
}

variable "cloudwatch_log_group_kms_key_id" {
  description = "The ARN of the KMS Key to use when encrypting log data"
  type        = string
  default     = null
}

variable "cloudwatch_log_group_class" {
  description = "Specifies the log class of the log group. Valid values are: STANDARD or INFREQUENT_ACCESS"
  type        = string
  default     = null
}

variable "cloudwatch_log_group_tags" {
  description = "Additional tags to apply to the CloudWatch log group"
  type        = map(string)
  default     = {}
}

variable "cloudwatch_log_group_force_destroy" {
  description = "When true (default), the CloudWatch log group can be deleted on terraform destroy. Set to false to protect it with lifecycle { prevent_destroy = true } (e.g. production)."
  type        = bool
  default     = true
}

variable "region" {
  description = "AWS region for CloudWatch log group"
  type        = string
  default     = "ap-southeast-2"
}

################################################################################
# Access & Authentication Configuration
################################################################################

variable "cluster_authentication_mode" {
  description = "Authentication mode for the EKS cluster. Valid values: CONFIG_MAP, API, API_AND_CONFIG_MAP. Defaults to API_AND_CONFIG_MAP when capabilities are enabled, otherwise CONFIG_MAP."
  type        = string
  default     = "API_AND_CONFIG_MAP"

  validation {
    condition     = contains(["CONFIG_MAP", "API", "API_AND_CONFIG_MAP"], var.cluster_authentication_mode)
    error_message = "cluster_authentication_mode must be one of: CONFIG_MAP, API, API_AND_CONFIG_MAP"
  }
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Indicates whether or not to add the cluster creator (the identity used by Terraform) as an administrator via access entry"
  type        = bool
  default     = false
}

variable "access_entries" {
  description = "Map of access entries to add to the cluster"
  type = map(object({
    # Access entry
    kubernetes_groups = optional(list(string))
    principal_arn     = string
    type              = optional(string, "STANDARD")
    user_name         = optional(string)
    tags              = optional(map(string), {})
    # Access policy association
    policy_associations = optional(map(object({
      policy_arn = string
      access_scope = object({
        namespaces = optional(list(string))
        type       = string
      })
    })), {})
  }))
  default = {}
}

################################################################################
# Encryption Configuration
################################################################################

variable "create_kms_key" {
  description = "Controls if a KMS key for cluster encryption should be created"
  type        = bool
  default     = true
}

variable "cluster_encryption_config_key_arn" {
  description = "ARN of the KMS key to use for encrypting Kubernetes secrets"
  type        = string
  default     = null
}

variable "cluster_encryption_config_resources" {
  description = "List of strings with resources to be encrypted. Valid values: secrets"
  type        = list(string)
  default     = ["secrets"]
}

################################################################################
# Addons Configuration
################################################################################

variable "addons" {
  description = "Map of EKS addons to enable"
  type = map(object({
    addon_version               = optional(string)
    before_compute              = optional(bool, false)
    configuration_values        = optional(string)
    resolve_conflicts_on_create = optional(string, "OVERWRITE")
    resolve_conflicts_on_update = optional(string, "OVERWRITE")
    service_account_role_arn    = optional(string)
  }))
  default = {}
}

variable "enable_aws_load_balancer_controller" {
  description = "Whether to create IAM role for AWS Load Balancer Controller (IRSA)"
  type        = bool
  default     = false
}

variable "enable_cluster_autoscaler_iam" {
  description = "Whether to create IAM role for Cluster Autoscaler (IRSA or Pod Identity per cluster_autoscaler_identity_type). For EC2 managed node groups only; not supported with enable_automode. When true, adds k8s.io/cluster-autoscaler/* tags to managed node groups for ASG autodiscovery."
  type        = bool
  default     = false
}

variable "enable_ebs_csi_driver" {
  description = "Whether to create IAM role for EBS CSI driver (IRSA or Pod Identity per ebs_csi_driver_identity_type)"
  type        = bool
  default     = false
}

variable "enable_external_dns" {
  description = "Whether to create IAM role for ExternalDNS (IRSA or Pod Identity per external_dns_identity_type)"
  type        = bool
  default     = false
}

variable "enable_secrets_manager" {
  description = "Whether to create IAM role for Secrets Manager (IRSA or Pod Identity per secrets_manager_identity_type)"
  type        = bool
  default     = false
}

variable "enable_karpenter" {
  description = "Whether to create Karpenter IAM (controller + node roles), interruption SQS queue, EventBridge rules, and EKS access entry for the node role (via terraform-aws-modules/eks/karpenter). Mutually exclusive with enable_automode."
  type        = bool
  default     = false
}

variable "karpenter_identity_type" {
  description = "Credential mode for the Karpenter controller. Only pod_identity is wired (EKS Pod Identity association); use eks-pod-identity-agent addon."
  type        = string
  default     = "pod_identity"

  validation {
    condition     = contains(["pod_identity"], var.karpenter_identity_type)
    error_message = "karpenter_identity_type must be 'pod_identity'."
  }
}

variable "karpenter_namespace" {
  description = "Kubernetes namespace for the Karpenter controller service account (must match GitOps Helm)."
  type        = string
  default     = "karpenter"
}

variable "karpenter_service_account" {
  description = "Kubernetes service account name for Karpenter (must match Helm chart)."
  type        = string
  default     = "karpenter"
}

variable "karpenter_discovery_subnet_ids" {
  description = "Private subnet IDs to tag with karpenter.sh/discovery = cluster name for Karpenter subnet discovery."
  type        = list(string)
  default     = []
}

################################################################################
# Pod Identity Configuration (alternative to IRSA per component)
################################################################################

variable "aws_load_balancer_controller_identity_type" {
  description = "Identity type for AWS Load Balancer Controller. Use 'pod_identity' to create Pod Identity association; requires eks-pod-identity-agent addon."
  type        = string
  default     = "irsa"

  validation {
    condition     = contains(["irsa", "pod_identity"], var.aws_load_balancer_controller_identity_type)
    error_message = "aws_load_balancer_controller_identity_type must be 'irsa' or 'pod_identity'."
  }
}

variable "aws_lb_controller_namespace" {
  description = "Kubernetes namespace for AWS Load Balancer Controller service account (Pod Identity). Used when aws_load_balancer_controller_identity_type = 'pod_identity'."
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "aws_lb_controller_service_account" {
  description = "Kubernetes service account name for AWS Load Balancer Controller (Pod Identity)."
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "external_dns_identity_type" {
  description = "Identity type for External DNS. Use 'pod_identity' to create Pod Identity association; requires eks-pod-identity-agent addon."
  type        = string
  default     = "irsa"

  validation {
    condition     = contains(["irsa", "pod_identity"], var.external_dns_identity_type)
    error_message = "external_dns_identity_type must be 'irsa' or 'pod_identity'."
  }
}

variable "external_dns_namespace" {
  description = "Kubernetes namespace for External DNS service account (Pod Identity). Used when external_dns_identity_type = 'pod_identity'."
  type        = string
  default     = "external-dns"
}

variable "external_dns_service_account" {
  description = "Kubernetes service account name for External DNS (Pod Identity)."
  type        = string
  default     = "external-dns"
}

variable "ebs_csi_driver_identity_type" {
  description = "Identity type for EBS CSI driver. Use 'pod_identity' to create Pod Identity association; requires eks-pod-identity-agent addon."
  type        = string
  default     = "irsa"

  validation {
    condition     = contains(["irsa", "pod_identity"], var.ebs_csi_driver_identity_type)
    error_message = "ebs_csi_driver_identity_type must be 'irsa' or 'pod_identity'."
  }
}

variable "ebs_csi_driver_namespace" {
  description = "Kubernetes namespace for EBS CSI driver service account. Used for IRSA OIDC condition and when ebs_csi_driver_identity_type = 'pod_identity'."
  type        = string
  default     = "aws-ebs-csi-driver"
}

variable "ebs_csi_driver_service_account" {
  description = "Kubernetes service account name for EBS CSI driver. Used for IRSA OIDC condition and when ebs_csi_driver_identity_type = 'pod_identity'."
  type        = string
  default     = "ebs-csi-controller-sa"
}

variable "cluster_autoscaler_identity_type" {
  description = "Identity type for Cluster Autoscaler. Use 'pod_identity' to create Pod Identity association; requires eks-pod-identity-agent addon."
  type        = string
  default     = "irsa"

  validation {
    condition     = contains(["irsa", "pod_identity"], var.cluster_autoscaler_identity_type)
    error_message = "cluster_autoscaler_identity_type must be 'irsa' or 'pod_identity'."
  }
}

variable "cluster_autoscaler_namespace" {
  description = "Kubernetes namespace for Cluster Autoscaler service account. Used for IRSA OIDC condition and when cluster_autoscaler_identity_type = 'pod_identity'."
  type        = string
  default     = "kube-system"
}

variable "cluster_autoscaler_service_account" {
  description = "Kubernetes service account name for Cluster Autoscaler. Used for IRSA OIDC condition and when cluster_autoscaler_identity_type = 'pod_identity'."
  type        = string
  default     = "cluster-autoscaler"
}

variable "secrets_manager_identity_type" {
  description = "Identity type for Secrets Manager. Use 'pod_identity' to create Pod Identity association; requires eks-pod-identity-agent addon."
  type        = string
  default     = "irsa"

  validation {
    condition     = contains(["irsa", "pod_identity"], var.secrets_manager_identity_type)
    error_message = "secrets_manager_identity_type must be 'irsa' or 'pod_identity'."
  }
}

variable "secrets_manager_associations" {
  description = "List of {namespace, service_account} for Pod Identity / IRSA. Each entry gets a Pod Identity association (or IRSA subject). Use app namespaces (e.g. sm-operator-system). Do not use 'default' or 'kube-system'."
  type = list(object({
    namespace       = string
    service_account = string
  }))
  default = []
}

variable "secrets_manager_secret_name_prefixes" {
  description = "List of secret name prefixes (e.g. ['bitwarden/sm-operator']) for least-privilege policy. When non-empty, creates custom policy with GetSecretValue+DescribeSecret instead of AWSSecretsManagerClientReadOnlyAccess."
  type        = list(string)
  default     = []
}

variable "secrets_manager_enable_parameter_store" {
  description = "Whether to also attach AmazonSSMReadOnlyAccess for AWS Systems Manager Parameter Store. Use when application pods need to read parameters in addition to secrets."
  type        = bool
  default     = false
}

################################################################################
# S3 (IRSA or EKS Pod Identity)
################################################################################

variable "enable_s3" {
  description = "Whether to create IAM roles for S3 access (IRSA or Pod Identity per s3_identity_type). One role per s3_access entry."
  type        = bool
  default     = false
}

variable "s3_identity_type" {
  description = "Identity type for S3. Use 'pod_identity' to create Pod Identity associations; requires eks-pod-identity-agent addon."
  type        = string
  default     = "irsa"

  validation {
    condition     = contains(["irsa", "pod_identity"], var.s3_identity_type)
    error_message = "s3_identity_type must be 'irsa' or 'pod_identity'."
  }
}

variable "s3_access" {
  description = "List of S3 access configs. Each entry gets its own IAM role (namespace + service_account + bucket_arns + read_only). Do not use namespace 'default' or 'kube-system'."
  type = list(object({
    namespace       = string
    service_account = string
    bucket_arns     = list(string)
    read_only       = bool
  }))
  default = []
}

variable "enable_sqs_access" {
  description = "Whether to create IAM roles for SQS access (IRSA or Pod Identity per sqs_identity_type). One role per sqs_access entry."
  type        = bool
  default     = false
}

variable "sqs_identity_type" {
  description = "Identity type for SQS access. Use 'pod_identity' to create Pod Identity associations; requires eks-pod-identity-agent addon."
  type        = string
  default     = "irsa"

  validation {
    condition     = contains(["irsa", "pod_identity"], var.sqs_identity_type)
    error_message = "sqs_identity_type must be 'irsa' or 'pod_identity'."
  }
}

variable "sqs_access" {
  description = "List of SQS access configs. Each entry gets its own IAM role (namespace + service_account + queue_arns + mode). Do not use namespace 'default' or 'kube-system'."
  type = list(object({
    namespace       = string
    service_account = string
    queue_arns      = list(string)
    mode            = optional(string, "consumer") # consumer, read_only
  }))
  default = []
}

variable "enable_kinesis_access" {
  description = "Whether to create IAM roles for Kinesis access (IRSA or Pod Identity per kinesis_identity_type). One role per kinesis_access entry."
  type        = bool
  default     = false
}

variable "kinesis_identity_type" {
  description = "Identity type for Kinesis access. Use 'pod_identity' to create Pod Identity associations; requires eks-pod-identity-agent addon."
  type        = string
  default     = "irsa"

  validation {
    condition     = contains(["irsa", "pod_identity"], var.kinesis_identity_type)
    error_message = "kinesis_identity_type must be 'irsa' or 'pod_identity'."
  }
}

variable "kinesis_access" {
  description = "List of Kinesis access configs. Each entry gets its own IAM role (namespace + service_account + stream_arns + mode). Do not use namespace 'default' or 'kube-system'."
  type = list(object({
    namespace       = string
    service_account = string
    stream_arns     = list(string)
    mode            = optional(string, "consumer") # consumer, read_only
  }))
  default = []
}

variable "enable_dynamodb_access" {
  description = "Whether to create IAM roles for DynamoDB access (IRSA or Pod Identity per dynamodb_identity_type). One role per dynamodb_access entry."
  type        = bool
  default     = false
}

variable "dynamodb_identity_type" {
  description = "Identity type for DynamoDB access. Use 'pod_identity' to create Pod Identity associations; requires eks-pod-identity-agent addon."
  type        = string
  default     = "irsa"

  validation {
    condition     = contains(["irsa", "pod_identity"], var.dynamodb_identity_type)
    error_message = "dynamodb_identity_type must be 'irsa' or 'pod_identity'."
  }
}

variable "dynamodb_access" {
  description = "List of DynamoDB access configs. Each entry gets its own IAM role (namespace + service_account + table_arns + mode). Do not use namespace 'default' or 'kube-system'."
  type = list(object({
    namespace       = string
    service_account = string
    table_arns      = list(string)
    mode            = optional(string, "read_only") # read_only, read_write
  }))
  default = []
}

variable "addon_identity_type" {
  description = "Identity type for addons that need IAM (e.g. EBS CSI driver). Use 'pod_identity' to create Pod Identity associations; requires eks-pod-identity-agent addon and addon_service_accounts."
  type        = string
  default     = "irsa"

  validation {
    condition     = contains(["irsa", "pod_identity"], var.addon_identity_type)
    error_message = "addon_identity_type must be 'irsa' or 'pod_identity'."
  }
}

variable "addon_service_accounts" {
  description = "Map of addon name to namespace and service account for Pod Identity. Required when addon_identity_type = 'pod_identity' for addons that need a role (e.g. aws-ebs-csi-driver)."
  type = map(object({
    namespace = string
    name      = string
  }))
  default = {}
}

################################################################################
# Capabilities Configuration
################################################################################

variable "capabilities" {
  description = <<-EOD
    Map of EKS capabilities to enable. Valid keys: ack, kro, argocd. Argo CD requires configuration.argo_cd.aws_idc (Identity Center). delete_propagation_policy currently only supports RETAIN.

    Security (see https://docs.aws.amazon.com/eks/latest/userguide/capabilities-security.html): Capability role must be in the same account as the cluster; when the module creates the role, the trust policy allows capabilities.eks.amazonaws.com. Least privilege: prefer scoping IAM to specific services, actions, and resources; avoid broad wildcards when possible (Configure ACK permissions, Security considerations for EKS Capabilities). kro: no IAM permissions required; use empty iam_policy_arns or omit. Argo CD: no IAM required by default; optional permissions only for Secrets Manager, CodeConnections, or ECR if used. Argo CD namespace: keep only Argo CD-relevant secrets in the configured namespace (default argocd) for namespace isolation.
  EOD
  type = map(object({
    role_arn        = optional(string)
    iam_policy_arns = optional(map(string), {})
    # Argo CD: list of CodeConnections connection ARNs for repo access (codeconnections:UseConnection, GetConnection). Use submodule modules/argocd-codeconnections to create connections and attach policy, or pass ARNs here for root module to attach.
    code_connection_arns = optional(list(string), [])
    # Optional: associate additional EKS access entry policies (e.g. AmazonEKSSecretReaderPolicy for ACK controllers that read secrets).
    access_entry_policy_associations = optional(list(object({
      policy_arn = string
      access_scope = optional(object({
        type       = string # "cluster" or "namespace"
        namespaces = optional(list(string), [])
      }), { type = "cluster", namespaces = [] })
    })), [])
    # Argo CD only. Optional for ACK/KRO. For Argo CD, aws_idc is required for authentication.
    configuration = optional(object({
      argo_cd = optional(object({
        namespace = optional(string)
        aws_idc = optional(object({
          idc_instance_arn = string
          idc_region       = optional(string)
        }))
        rbac_role_mapping = optional(list(object({
          role = string # ADMIN, EDITOR, VIEWER
          identity = list(object({
            type = string # SSO_USER, SSO_GROUP
            id   = string
          }))
        })))
        network_access = optional(object({
          vpce_ids = optional(list(string))
        }))
      }))
    }))
    delete_propagation_policy = optional(string, "RETAIN")
  }))
  default = {}

  validation {
    condition     = alltrue([for k in keys(var.capabilities) : contains(["ack", "kro", "argocd"], k)])
    error_message = "Capability keys must be one of: ack, kro, argocd."
  }

  validation {
    condition     = alltrue([for k, v in var.capabilities : k != "argocd" || try(v.configuration.argo_cd.aws_idc, null) != null])
    error_message = "Argo CD capability requires configuration.argo_cd.aws_idc (Identity Center) to be set."
  }
}

################################################################################
# Auto Mode Configuration
################################################################################

variable "enable_automode" {
  description = "Enable EKS Auto Mode. Mutually exclusive with eks_managed_node_groups."
  type        = bool
  default     = false
}

variable "automode_node_pools" {
  description = "Built-in node pool types to enable with Auto Mode. Only used when enable_automode = true."
  type        = list(string)
  default     = ["system", "general-purpose"]
}

################################################################################
# Fargate Configuration
################################################################################

variable "fargate_profiles" {
  description = "Map of EKS Fargate profile configurations (key = profile name). Fargate pods require private subnets with NAT gateway access. Per-profile subnet_ids override the module-level subnet_ids. Pod execution IAM is controlled by create_fargate_pod_execution_role / fargate_pod_execution_role_arn. Access entry behavior: create_fargate_access_entry and fargate_access_entry_type when cluster_authentication_mode is API or API_AND_CONFIG_MAP; for CONFIG_MAP-only clusters you must grant the pod execution role access yourself (e.g. aws-auth)."
  type = map(object({
    selectors = list(object({
      namespace = string
      labels    = optional(map(string))
    }))
    subnet_ids = optional(list(string))
    tags       = optional(map(string), {})
  }))
  default = {}

  validation {
    condition     = alltrue([for _, p in var.fargate_profiles : length(p.selectors) > 0])
    error_message = "Each fargate_profiles entry must include at least one selector."
  }
}

variable "create_fargate_pod_execution_role" {
  description = "Whether to create the shared IAM role for Fargate pod execution. If false, set fargate_pod_execution_role_arn to an existing role ARN."
  type        = bool
  default     = true
}

variable "fargate_pod_execution_role_arn" {
  description = "Existing IAM role ARN for Fargate pod execution when create_fargate_pod_execution_role is false. Leave null when the module creates the role."
  type        = string
  default     = null

  validation {
    condition = (
      length(var.fargate_profiles) == 0
      || var.create_fargate_pod_execution_role
      || (try(var.fargate_pod_execution_role_arn, null) != null && var.fargate_pod_execution_role_arn != "")
    )
    error_message = "When fargate_profiles is non-empty and create_fargate_pod_execution_role is false, fargate_pod_execution_role_arn must be set to an existing IAM role ARN."
  }

  validation {
    condition     = var.create_fargate_pod_execution_role ? try(var.fargate_pod_execution_role_arn, null) == null : true
    error_message = "Do not set fargate_pod_execution_role_arn when create_fargate_pod_execution_role is true."
  }
}

variable "fargate_pod_execution_role_name" {
  description = "Name of the created Fargate pod execution IAM role (when create_fargate_pod_execution_role is true). Defaults to {name}-fargate-pod-execution."
  type        = string
  default     = null
}

variable "fargate_pod_execution_role_path" {
  description = "IAM path for the created Fargate pod execution role (when create_fargate_pod_execution_role is true)."
  type        = string
  default     = "/"
}

variable "fargate_pod_execution_role_permissions_boundary" {
  description = "ARN of a permissions boundary to attach to the created Fargate pod execution role (when create_fargate_pod_execution_role is true)."
  type        = string
  default     = null
}

variable "create_fargate_access_entry" {
  description = "Whether to create an EKS access entry for the Fargate pod execution principal. Ignored when cluster_authentication_mode is CONFIG_MAP (no entry is created)."
  type        = bool
  default     = true
}

variable "fargate_access_entry_type" {
  description = "Access entry type for the Fargate pod execution principal (when create_fargate_access_entry is true and auth is API-based). Must be a Fargate-compatible type accepted by AWS CreateAccessEntry."
  type        = string
  default     = "FARGATE_LINUX"

  validation {
    condition     = contains(["FARGATE_LINUX"], var.fargate_access_entry_type)
    error_message = "fargate_access_entry_type must be FARGATE_LINUX."
  }
}

################################################################################
# Node Group Configuration
################################################################################

variable "eks_managed_node_groups" {
  description = "Map of EKS managed node group configurations"
  type = map(object({
    name                       = optional(string)
    ami_type                   = optional(string, "AL2023_x86_64_STANDARD")
    instance_types             = optional(list(string), ["t3.medium"])
    min_size                   = optional(number, 1)
    max_size                   = optional(number, 3)
    desired_size               = optional(number, 2)
    disk_size                  = optional(number, 20)
    subnet_ids                 = optional(list(string))
    enable_bootstrap_user_data = optional(bool, true)
    metadata_options = optional(object({
      http_endpoint               = optional(string, "enabled")
      http_tokens                 = optional(string, "required")
      http_put_response_hop_limit = optional(number, 1)
    }))
    labels = optional(map(string), {})
    tags   = optional(map(string), {})
  }))
  default = {}

  validation {
    condition     = !(var.enable_automode && length(var.eks_managed_node_groups) > 0)
    error_message = "enable_automode and eks_managed_node_groups are mutually exclusive. Use one or the other."
  }
}
