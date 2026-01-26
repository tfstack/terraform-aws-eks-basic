# EKS Authentication Modes and Access Entry Management

## Overview

EKS supports three authentication modes for cluster access:

- `CONFIG_MAP` - Legacy mode using aws-auth ConfigMap (default when no capabilities)
- `API` - API-only authentication via EKS access entries
- `API_AND_CONFIG_MAP` - Hybrid mode supporting both methods (required for capabilities)

## Why Access Entries Are Needed

When EKS capabilities (ACK, KRO) are enabled, the cluster automatically switches to `API_AND_CONFIG_MAP` mode. In this mode:

1. **Capabilities** authenticate via the EKS API
2. **Nodes and pods** need explicit access entries to join the cluster
3. **Users and roles** need explicit access entries for kubectl/API access
4. The aws-auth ConfigMap alone is insufficient

## Access Entry Types

### Infrastructure Access Entries (Automatic)

The module automatically creates access entries for infrastructure resources:

- **EC2 Nodes**: `type = "EC2_LINUX"` - Allows worker nodes to join the cluster
- **Fargate Pods**: `type = "FARGATE_LINUX"` - Allows Fargate pods to schedule

These are created automatically when capabilities are enabled.

### User Access Entries (Manual)

For human users and CI/CD systems to access the cluster, you must explicitly grant access:

- **Type**: `STANDARD` - For IAM users/roles that need cluster access
- **Policy**: `AmazonEKSClusterAdminPolicy` - Grants full cluster admin permissions

#### Example: Granting Admin Access

```hcl
resource "aws_eks_access_entry" "cluster_admins" {
  for_each = toset(var.cluster_admin_arns)

  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "cluster_admin_policy" {
  for_each = toset(var.cluster_admin_arns)

  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.cluster_admins]
}
```

See the `eks-capabilities` example for a complete implementation.

## Implementation

### Conditional Logic

Access entries are created when:

- Any capability is enabled (ACK or KRO), OR
- `cluster_authentication_mode` is explicitly set to `API` or `API_AND_CONFIG_MAP`

```hcl
local.ec2_needs_access_entry = contains(var.compute_mode, "ec2") && (
  var.enable_ack_capability ||
  var.enable_kro_capability ||
  # var.enable_argocd_capability ||  # ArgoCD not currently supported
  var.cluster_authentication_mode != "CONFIG_MAP"
)
```

### Resource Types

- **EC2 Nodes**: Use `type = "EC2_LINUX"` access entry
- **Fargate Pods**: Use `type = "FARGATE_LINUX"` access entry
- **Users/Roles**: Use `type = "STANDARD"` access entry

### Deployment Order

1. EKS cluster created
2. IAM roles for nodes/pods created
3. Access entries created (if needed)
4. Node groups/Fargate profiles created

This ensures nodes have the credentials to authenticate before attempting to join.

## Backward Compatibility

| Scenario | Authentication Mode | Access Entries | Result |
| -------- | ----------------- | -------------- | ------- |
| No capabilities | CONFIG_MAP | Not created | aws-auth ConfigMap only |
| With capabilities | API_AND_CONFIG_MAP | Created | Both methods available |
| Explicit API mode | API | Created | API-only authentication |

## Troubleshooting

### Nodes Fail to Join

**Symptom**: `NodeCreationFailure: Instances failed to join the kubernetes cluster`

**Cause**: Cluster is in `API_AND_CONFIG_MAP` mode but node access entries weren't created

**Solution**: Verify node access entries exist:

```bash
aws eks list-access-entries --cluster-name <cluster-name>
```

### Fargate Pods Stuck Pending

**Symptom**: Fargate pods remain in `Pending` state

**Cause**: Missing Fargate pod access entry in API authentication mode

**Solution**: Check Fargate access entry exists and pod execution role matches

### User Cannot Access Cluster

**Symptom**: `Your current IAM principal doesn't have access to Kubernetes objects on this cluster`

**Cause**: Your IAM user/role doesn't have an EKS access entry

**Solution**: Add your IAM ARN to the cluster admin access entries:

```bash
# Option 1: Via AWS CLI
aws eks create-access-entry \
  --cluster-name <cluster-name> \
  --principal-arn <your-iam-arn> \
  --type STANDARD

aws eks associate-access-policy \
  --cluster-name <cluster-name> \
  --principal-arn <your-iam-arn> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster

# Option 2: Via Terraform (see eks-capabilities example)
# Add your ARN to cluster_admin_arns variable and apply
```

## References

- [EKS Access Entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)
- [EKS Authentication Modes](https://docs.aws.amazon.com/eks/latest/userguide/grant-k8s-access.html)
