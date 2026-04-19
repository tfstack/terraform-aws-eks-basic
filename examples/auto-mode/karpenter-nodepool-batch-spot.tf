resource "kubernetes_manifest" "karpenter_batch_spot_nodepool" {
  manifest = yamldecode(file("${path.module}/manifests/karpenter-nodepool-batch-spot.yaml"))

  depends_on = [module.eks]
}
