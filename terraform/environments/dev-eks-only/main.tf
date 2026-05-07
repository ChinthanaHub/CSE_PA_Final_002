terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Reference existing VPC
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = ["cse-pa-final-dev"]
  }
}

# Reference existing private subnets
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }

  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}

# Reference existing security group
data "aws_security_group" "eks_cluster" {
  filter {
    name   = "group-name"
    values = ["cse-pa-final-dev-eks-cluster-sg"]
  }

  vpc_id = data.aws_vpc.existing.id
}

# Reference existing IAM role
data "aws_iam_role" "eks_cluster" {
  name = "cse-pa-final-dev-eks-cluster-role"
}

# Reference existing KMS keys
data "aws_kms_key" "eks" {
  key_id = "alias/cse-pa-final-dev-eks"
}

data "aws_kms_key" "cloudwatch" {
  key_id = "alias/cse-pa-final-dev-cloudwatch"
}

# Reference existing IAM role for GitHub Actions
data "aws_iam_role" "github_actions" {
  name = "cse-pa-final-dev-github-actions-role"
}

# EKS Cluster module (referencing existing resources)
module "eks" {
  source = "../../modules/eks"

  cluster_name              = "cse-pa-final-dev-cluster"
  kubernetes_version        = var.kubernetes_version
  environment               = "dev"
  cluster_role_arn          = data.aws_iam_role.eks_cluster.arn
  private_subnet_ids        = data.aws_subnets.private.ids
  cluster_security_group_id = data.aws_security_group.eks_cluster.id
  endpoint_public_access    = true
  public_access_cidrs       = ["0.0.0.0/0"]
  kms_key_arn               = data.aws_kms_key.eks.arn
  cloudwatch_kms_key_arn    = data.aws_kms_key.cloudwatch.arn

  tags = {
    Project     = "CSE-PA-Final"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# AWS Auth ConfigMap for GitHub Actions access
resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = data.aws_iam_role.github_actions.arn
        username = "github-actions"
        groups   = ["system:masters"]
      }
    ])
  }

  depends_on = [module.eks]
}