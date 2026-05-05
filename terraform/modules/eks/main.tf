terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [var.cluster_security_group_id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  tags = var.tags

  depends_on = [var.cluster_role_arn]
}

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 30
  kms_key_id        = var.cloudwatch_kms_key_arn
  tags              = var.tags
}

# OIDC Provider for IRSA
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  tags            = var.tags
}

# Fargate Pod Execution Role
resource "aws_iam_role" "fargate_pod_execution" {
  name = "${var.cluster_name}-fargate-pod-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks-fargate-pods.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        ArnLike = {
          "aws:SourceArn" = "arn:aws:eks:*:*:fargateprofile/${var.cluster_name}/*"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "fargate_pod_execution" {
  role       = aws_iam_role.fargate_pod_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

# Fargate Profiles — one per namespace
resource "aws_eks_fargate_profile" "kube_system" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.cluster_name}-kube-system"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution.arn
  subnet_ids             = var.private_subnet_ids

  # Matches CoreDNS pods (label set by EKS addon)
  selector {
    namespace = "kube-system"
    labels    = { "k8s-app" = "kube-dns" }
  }

  tags       = var.tags
  depends_on = [aws_iam_role_policy_attachment.fargate_pod_execution]
}

resource "aws_eks_fargate_profile" "app" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.cluster_name}-app"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution.arn
  subnet_ids             = var.private_subnet_ids

  selector { namespace = "app" }

  tags       = var.tags
  depends_on = [aws_iam_role_policy_attachment.fargate_pod_execution]
}

resource "aws_eks_fargate_profile" "external_secrets" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.cluster_name}-external-secrets"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution.arn
  subnet_ids             = var.private_subnet_ids

  selector { namespace = "external-secrets" }

  tags       = var.tags
  depends_on = [aws_iam_role_policy_attachment.fargate_pod_execution]
}

resource "aws_eks_fargate_profile" "kyverno" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.cluster_name}-kyverno"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution.arn
  subnet_ids             = var.private_subnet_ids

  selector { namespace = "kyverno" }

  tags       = var.tags
  depends_on = [aws_iam_role_policy_attachment.fargate_pod_execution]
}

resource "aws_eks_fargate_profile" "monitoring" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.cluster_name}-monitoring"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution.arn
  subnet_ids             = var.private_subnet_ids

  selector { namespace = "monitoring" }

  tags       = var.tags
  depends_on = [aws_iam_role_policy_attachment.fargate_pod_execution]
}

# CoreDNS is the only addon needed on Fargate
# (kube-proxy and vpc-cni are managed by AWS on Fargate; ebs-csi is unsupported)
data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  addon_version               = data.aws_eks_addon_version.coredns.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags

  depends_on = [aws_eks_fargate_profile.kube_system]
}
