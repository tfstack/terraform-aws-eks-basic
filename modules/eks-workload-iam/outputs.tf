output "role_arn" {
  description = "ARN of the IAM role created for the workload."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role created for the workload."
  value       = aws_iam_role.this.name
}

output "pod_identity_association_id" {
  description = "ID of the EKS Pod Identity association, or null when identity_type = 'irsa'."
  value       = try(aws_eks_pod_identity_association.this[0].id, null)
}
