resource "kubernetes_manifest" "karpenter_accelerated_nodepool" {
  manifest = yamldecode(file("${path.module}/manifests/karpenter-nodepool-accelerated.yaml"))

  depends_on = [module.eks]
}
