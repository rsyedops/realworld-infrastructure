# Versions are resolved by EKS for the cluster's Kubernetes version rather than
# pinned here, so a control plane upgrade does not strand the addons.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  # NetworkPolicy is not enforced by the VPC CNI unless this is switched on, so
  # without it the policies applied to the workloads would be silently inert.
  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
  })

  tags = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.tags
}

# CoreDNS schedules onto worker nodes, so it cannot reconcile until a node group
# has registered.
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.tags

  depends_on = [aws_eks_node_group.this]
}
