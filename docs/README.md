# terraform-aws-eks-basic Documentation

This directory contains detailed documentation for the module's design decisions, architecture, and operational guides.

## Contents

- [Authentication & Access Management](authentication.md) - EKS access entries and RBAC configuration

## Quick Links

### Getting Started

- See [main README](../README.md) for basic usage and examples
- See [examples/basic](../examples/basic/) for a minimal configuration
- See [examples/ebs-web-app](../examples/ebs-web-app/) for a complete VPC + EKS setup
- See [examples/eks-capabilities](../examples/eks-capabilities/) for platform engineering with capabilities

### Key Concepts

**Access Management**: This module uses EKS Access Entries as the primary authentication mechanism. Access entries provide a modern, API-driven approach to managing Kubernetes RBAC without the legacy aws-auth ConfigMap.

**Node Groups**: EC2 managed node groups are configured via the `eks_managed_node_groups` variable, which provides full control over instance types, scaling, disk sizes, and metadata options.

**Addons**: EKS addons (CoreDNS, VPC CNI, EBS CSI Driver, etc.) are configured via the `addons` variable with flexible version control and IRSA support.

**Capabilities**: EKS Capabilities (ACK, KRO, ArgoCD) are optional features for platform engineering, configured via the `capabilities` variable.

## Architecture

The module is organized into focused files:

- `main.tf` - Core cluster, node groups, addons, and OIDC provider
- `access-entries.tf` - EKS access entries for authentication
- `capabilities.tf` - EKS Capabilities (ACK, KRO, ArgoCD)
- `capabilities-iam.tf` - IAM roles for capabilities
- `addons-iam.tf` - IAM roles for addons (IRSA)
- `locals.tf` - Computed values and configurations
- `cluster-auth.tf` - Cluster authentication data source
- `variables.tf` - Input variables
- `outputs.tf` - Output values
