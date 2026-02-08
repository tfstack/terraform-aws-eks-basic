################################################################################
# Data Source Values
################################################################################

locals {
  account_id = try(data.aws_caller_identity.current.account_id, "")
  partition  = try(data.aws_partition.current.partition, "")

  ################################################################################
  # Access Entry Configuration
  ################################################################################

  # Flatten out entries and policy associations so users can specify the policy
  # associations within a single entry
  flattened_access_entries = flatten([
    for entry_key, entry_val in var.access_entries : [
      for pol_key, pol_val in entry_val.policy_associations :
      merge(
        {
          principal_arn = entry_val.principal_arn
          entry_key     = entry_key
          pol_key       = pol_key
        },
        { for k, v in {
          association_policy_arn              = pol_val.policy_arn
          association_access_scope_type       = pol_val.access_scope.type
          association_access_scope_namespaces = try(pol_val.access_scope.namespaces, null)
        } : k => v if !contains(["EC2_LINUX", "EC2_WINDOWS", "FARGATE_LINUX", "HYBRID_LINUX"], lookup(entry_val, "type", "STANDARD")) },
      )
    ]
  ])

  ################################################################################
  # Encryption Configuration
  ################################################################################

  # Determine which KMS key ARN to use for cluster encryption
  # Priority: 1) Provided key ARN, 2) Created key ARN, 3) null
  this_key_arn = coalesce(
    var.cluster_encryption_config_key_arn,
    try(aws_kms_key.this[0].arn, null)
  )

  # Format user_data in MIME multipart format for EKS launch templates
  # This is required when using launch templates with managed node groups
  node_group_user_data = {
    for k, v in var.eks_managed_node_groups : k => try(v.enable_bootstrap_user_data, true) ? base64encode(
      join("", [
        "MIME-Version: 1.0\n",
        "Content-Type: multipart/mixed; boundary=\"//\"\n",
        "\n",
        "--//\n",
        "Content-Type: text/cloud-config; charset=\"us-ascii\"\n",
        "MIME-Version: 1.0\n",
        "Content-Transfer-Encoding: 7bit\n",
        "Content-Disposition: attachment; filename=\"nodeconfig.yaml\"\n",
        "\n",
        templatefile("${path.module}/templates/al2023_user_data.tpl", {
          enable_bootstrap_user_data = true
          cluster_name               = aws_eks_cluster.this.name
          cluster_endpoint           = aws_eks_cluster.this.endpoint
          cluster_auth_base64        = aws_eks_cluster.this.certificate_authority[0].data
          cluster_service_cidr       = try(aws_eks_cluster.this.kubernetes_network_config[0].service_ipv4_cidr, null)
        }),
        "\n",
        "--//--"
      ])
    ) : null
  }

  ################################################################################
  # Capabilities Configuration
  ################################################################################

  # Map capability keys to AWS capability types
  capability_types = {
    ack    = "ACK"
    kro    = "KRO"
    argocd = "ARGOCD"
  }

  # Determine if any capabilities are enabled
  capabilities_enabled = length(var.capabilities) > 0
}
