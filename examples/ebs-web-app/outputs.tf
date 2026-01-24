# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

# EKS Cluster Outputs
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_ca_data
  sensitive   = true
}

# Kubernetes Resources
output "web_app_service_name" {
  description = "Name of the web app Kubernetes service"
  value       = kubernetes_service_v1.web_app.metadata[0].name
}

output "web_app_pvc_name" {
  description = "Name of the PersistentVolumeClaim"
  value       = kubernetes_persistent_volume_claim_v1.web_app_storage.metadata[0].name
}

output "web_app_deployment_name" {
  description = "Name of the web app deployment"
  value       = kubernetes_deployment_v1.web_app.metadata[0].name
}

# Instructions
output "access_instructions" {
  description = "Instructions to access the web application"
  value       = <<-EOT
    To access the web application:

    1. Port forward the service:
       kubectl port-forward service/web-app 8080:80

    2. Open http://localhost:8080 in your browser

    3. Verify the EBS volume is attached:
       kubectl get pvc
       kubectl describe pvc web-app-storage

    4. Check the pod is using the volume:
       kubectl get pods
       kubectl describe pod -l app=web-app
  EOT
}
