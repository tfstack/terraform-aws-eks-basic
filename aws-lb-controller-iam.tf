################################################################################
# AWS Load Balancer Controller IAM Role (IRSA)
# IAM role required for AWS Load Balancer Controller Helm chart
################################################################################

# IAM assume role policy document for AWS Load Balancer Controller
data "aws_iam_policy_document" "aws_lb_controller_assume_role" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc_provider[0].arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM role for AWS Load Balancer Controller
resource "aws_iam_role" "aws_lb_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name               = "${var.name}-aws-lb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.aws_lb_controller_assume_role[0].json

  tags = var.tags

  depends_on = [
    aws_iam_openid_connect_provider.oidc_provider
  ]
}

# Attach AWS managed policy for Elastic Load Balancing
resource "aws_iam_role_policy_attachment" "aws_lb_controller" {
  for_each = var.enable_aws_load_balancer_controller ? {
    elastic_load_balancing = "arn:${data.aws_partition.current.partition}:iam::aws:policy/ElasticLoadBalancingFullAccess"
    ec2                    = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2FullAccess"
  } : {}

  role       = aws_iam_role.aws_lb_controller[0].name
  policy_arn = each.value
}

# IAM policy document for AWS Load Balancer Controller WAF, WAF Regional, and Shield permissions
data "aws_iam_policy_document" "aws_lb_controller_waf" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  statement {
    sid    = "WAFv2Permissions"
    effect = "Allow"
    actions = [
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "wafv2:ListWebACLs"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "WAFRegionalPermissions"
    effect = "Allow"
    actions = [
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "waf-regional:ListWebACLs"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ShieldPermissions"
    effect = "Allow"
    actions = [
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection"
    ]
    resources = ["*"]
  }
}

# IAM policy for AWS Load Balancer Controller WAF permissions
resource "aws_iam_role_policy" "aws_lb_controller_waf" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name   = "${var.name}-aws-lb-controller-waf-policy"
  role   = aws_iam_role.aws_lb_controller[0].id
  policy = data.aws_iam_policy_document.aws_lb_controller_waf[0].json
}
