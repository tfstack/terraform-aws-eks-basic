################################################################################
# EKS Cluster Authentication Data Source
################################################################################

data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.this.name
}
