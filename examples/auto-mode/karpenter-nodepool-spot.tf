resource "kubernetes_manifest" "karpenter_spot_nodepool" {
  manifest = yamldecode(file("${path.module}/manifests/karpenter-nodepool-spot.yaml"))

  depends_on = [module.eks]
}
