# EKS Access Entry Management

## Overview

This module uses **EKS Access Entries** as the primary authentication mechanism for cluster access. Access entries provide a modern, API-driven approach to managing Kubernetes RBAC permissions without needing to maintain the legacy aws-auth ConfigMap.

## Access Entry Types

The module implements access entries in two ways:

### 1. Automatic Access Entries (Infrastructure)

The module automatically creates access entries for:

- **EC2 Nodes** (`type = "EC2_LINUX"`) - Allows worker nodes to join and communicate with the cluster
  - Created automatically when `eks_managed_node_groups` is configured
  - Uses the node IAM role ARN
  - Grants necessary permissions for kubelet, kube-proxy, and other system components

### 2. User-Defined Access Entries

For human users, service accounts, and CI/CD systems, you define access entries using the `access_entries` variable:

```hcl
access_entries = {
  admin_user = {
    principal_arn = "arn:aws:iam::123456789012:user/admin"
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

  developer_role = {
    principal_arn = "arn:aws:iam::123456789012:role/developer"
    type          = "STANDARD"
    policy_associations = {
      edit = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
        access_scope = {
          type       = "namespace"
          namespaces = ["dev", "staging"]
        }
      }
    }
  }
}
```

## Available EKS Access Policies

AWS provides several managed access policies:

- `AmazonEKSClusterAdminPolicy` - Full cluster admin access (cluster-admin)
- `AmazonEKSAdminPolicy` - Admin access with some limitations
- `AmazonEKSEditPolicy` - Edit resources in namespaces
- `AmazonEKSViewPolicy` - Read-only access to resources

## Implementation Details

### EC2 Node Access Entries

The module automatically creates access entries for EC2 nodes when node groups are defined:

```hcl
resource "aws_eks_access_entry" "node" {
  count = length(var.eks_managed_node_groups) > 0 ? 1 : 0

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.eks_nodes[0].arn
  type          = "EC2_LINUX"
}
```

### User Access Entries

User-defined access entries are created from the `access_entries` variable with support for:

- Multiple policy associations per entry
- Namespace-scoped or cluster-scoped access
- Custom usernames and Kubernetes groups

## Access Scope Types

Access policies can be scoped at two levels:

1. **Cluster Scope** - Permissions apply across the entire cluster:

   ```hcl
   access_scope = {
     type = "cluster"
   }
   ```

2. **Namespace Scope** - Permissions apply only to specific namespaces:

   ```hcl
   access_scope = {
     type       = "namespace"
     namespaces = ["app1", "app2"]
   }
   ```

## Examples

### Basic Admin Access

```hcl
module "eks" {
  source = "tfstack/eks-basic/aws"

  name               = "my-cluster"
  kubernetes_version = "1.35"
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-1", "subnet-2"]

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
```

### Multiple Users with Different Permissions

```hcl
module "eks" {
  source = "tfstack/eks-basic/aws"

  name               = "my-cluster"
  kubernetes_version = "1.35"
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-1", "subnet-2"]

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

    developers = {
      principal_arn = "arn:aws:iam::123456789012:role/developer-role"
      type          = "STANDARD"
      policy_associations = {
        edit = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = ["development"]
          }
        }
      }
    }

    viewers = {
      principal_arn = "arn:aws:iam::123456789012:role/viewer-role"
      type          = "STANDARD"
      policy_associations = {
        view = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}
```

## Troubleshooting

### Nodes Fail to Join

**Symptom**: `NodeCreationFailure: Instances failed to join the kubernetes cluster`

**Cause**: Node access entry was not created or IAM role ARN mismatch

**Solution**:

1. Verify the node access entry exists:

   ```bash
   aws eks list-access-entries --cluster-name <cluster-name>
   ```

2. Check the node IAM role matches:

   ```bash
   aws eks describe-access-entry \
     --cluster-name <cluster-name> \
     --principal-arn <node-role-arn>
   ```

### User Cannot Access Cluster

**Symptom**: `Error: You must be logged in to the server (Unauthorized)` or `Your current IAM principal doesn't have access to Kubernetes objects on this cluster`

**Cause**: Your IAM user/role doesn't have an EKS access entry

**Solution**: Add your IAM ARN to the `access_entries` variable:

```hcl
access_entries = {
  my_user = {
    principal_arn = "arn:aws:iam::123456789012:user/myuser"
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
```

Or use AWS CLI:

```bash
aws eks create-access-entry \
  --cluster-name <cluster-name> \
  --principal-arn <your-iam-arn> \
  --type STANDARD

aws eks associate-access-policy \
  --cluster-name <cluster-name> \
  --principal-arn <your-iam-arn> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

### Wrong Permissions

**Symptom**: `Error from server (Forbidden): <resource> is forbidden: User <username> cannot <action> resource <resource>`

**Cause**: The access policy doesn't grant sufficient permissions

**Solution**: Update the policy association to a higher permission level or add additional policy associations

## Migration from aws-auth ConfigMap

If you're migrating from aws-auth ConfigMap to access entries:

1. **Inventory existing access**: Document all entries in your aws-auth ConfigMap
2. **Create access entries**: Convert each entry to the new `access_entries` format
3. **Test access**: Verify all users can still access the cluster
4. **Remove aws-auth**: The ConfigMap is no longer needed with access entries

## Best Practices

1. **Principle of Least Privilege**: Grant only the minimum permissions needed
2. **Use Namespace Scoping**: Limit access to specific namespaces when possible
3. **Separate Roles**: Use different IAM roles for different permission levels
4. **Document Access**: Keep a clear record of who has what access
5. **Regular Audits**: Periodically review access entries and remove unused ones

## References

- [EKS Access Entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)
- [EKS Access Policies](https://docs.aws.amazon.com/eks/latest/userguide/access-policies.html)
- [Grant IAM users access to Kubernetes](https://docs.aws.amazon.com/eks/latest/userguide/grant-k8s-access.html)
