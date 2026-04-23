resource "kubernetes_manifest" "karpenter_gpu_nodepool" {
  manifest = yamldecode(file("${path.module}/manifests/karpenter-nodepool-gpu.yaml"))

  depends_on = [module.eks]
}
