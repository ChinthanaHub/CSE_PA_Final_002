terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

# EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster" {
  name = "${var.name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# EKS Node Group IAM Role
resource "aws_iam_role" "eks_node_group" {
  name = "${var.name}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_node_group.name
}

# GitHub Actions OIDC Role
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(var.tags, { Name = "${var.name}-github-oidc" })
}

resource "aws_iam_role" "github_actions" {
  name = "${var.name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
      }
    }]
  })

  tags = var.tags
}

# Policy 1 — compute & networking (EC2, EKS, ECR, IAM, KMS)
resource "aws_iam_policy" "github_actions" {
  name        = "${var.name}-github-actions-policy"
  description = "GitHub Actions: compute and networking management"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSManage"
        Effect = "Allow"
        Action = [
          "kms:CreateKey", "kms:DescribeKey", "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus", "kms:ListKeyPolicies", "kms:ListResourceTags",
          "kms:PutKeyPolicy", "kms:EnableKeyRotation", "kms:DisableKeyRotation",
          "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion",
          "kms:CreateAlias", "kms:DeleteAlias", "kms:UpdateAlias", "kms:ListAliases",
          "kms:Decrypt", "kms:GenerateDataKey", "kms:GenerateDataKeyWithoutPlaintext",
          "kms:Encrypt", "kms:ReEncrypt*", "kms:TagResource", "kms:UntagResource",
          "kms:EnableKey", "kms:DisableKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMManage"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole",
          "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy",
          "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy",
          "iam:GetPolicyVersion", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion",
          "iam:SetDefaultPolicyVersion", "iam:ListPolicyVersions",
          "iam:TagPolicy", "iam:UntagPolicy",
          "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:TagOpenIDConnectProvider", "iam:AddClientIDToOpenIDConnectProvider",
          "iam:RemoveClientIDFromOpenIDConnectProvider",
          "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile", "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:PassRole", "iam:GetRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
          "iam:ListRoles", "iam:ListPolicies"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name}-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.name}-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${var.name}-*"
        ]
      },
      {
        Sid    = "EC2VPCManage"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs", "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
          "ec2:DescribeSubnets", "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
          "ec2:DescribeInternetGateways", "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
          "ec2:DescribeNatGateways", "ec2:CreateNatGateway", "ec2:DeleteNatGateway",
          "ec2:DescribeAddresses", "ec2:AllocateAddress", "ec2:ReleaseAddress",
          "ec2:AssociateAddress", "ec2:DisassociateAddress",
          "ec2:DescribeRouteTables", "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
          "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable", "ec2:CreateRoute", "ec2:DeleteRoute",
          "ec2:DescribeSecurityGroups", "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress",
          "ec2:UpdateSecurityGroupRuleDescriptionsIngress", "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
          "ec2:DescribeFlowLogs", "ec2:CreateFlowLogs", "ec2:DeleteFlowLogs",
          "ec2:DescribeAvailabilityZones", "ec2:DescribeRegions",
          "ec2:DescribeLaunchTemplates", "ec2:DescribeLaunchTemplateVersions",
          "ec2:CreateLaunchTemplate", "ec2:DeleteLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion", "ec2:DeleteLaunchTemplateVersions", "ec2:ModifyLaunchTemplate",
          "ec2:DescribeInstances", "ec2:DescribeInstanceTypes", "ec2:DescribeImages",
          "ec2:DescribeTags", "ec2:CreateTags", "ec2:DeleteTags",
          "ec2:DescribeAccountAttributes", "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeNetworkAcls", "ec2:DescribeVpcAttribute",
          "ec2:DescribeKeyPairs", "ec2:DescribeSecurityGroupRules"
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSManage"
        Effect = "Allow"
        Action = [
          "eks:CreateCluster", "eks:DeleteCluster", "eks:DescribeCluster",
          "eks:UpdateClusterConfig", "eks:UpdateClusterVersion",
          "eks:CreateNodegroup", "eks:DeleteNodegroup", "eks:DescribeNodegroup",
          "eks:UpdateNodegroupConfig", "eks:UpdateNodegroupVersion",
          "eks:CreateAddon", "eks:DeleteAddon", "eks:DescribeAddon", "eks:UpdateAddon", "eks:ListAddons",
          "eks:AssociateIdentityProviderConfig", "eks:DescribeIdentityProviderConfig",
          "eks:DisassociateIdentityProviderConfig",
          "eks:CreateAccessEntry", "eks:DeleteAccessEntry", "eks:DescribeAccessEntry",
          "eks:AssociateAccessPolicy", "eks:DisassociateAccessPolicy",
          "eks:ListAccessEntries", "eks:ListAssociatedAccessPolicies",
          "eks:TagResource", "eks:UntagResource", "eks:ListTagsForResource",
          "eks:ListClusters", "eks:ListNodegroups", "eks:DescribeAddonVersions"
        ]
        Resource = "*"
      },
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRManage"
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository", "ecr:DeleteRepository", "ecr:DescribeRepositories",
          "ecr:GetRepositoryPolicy", "ecr:SetRepositoryPolicy", "ecr:DeleteRepositoryPolicy",
          "ecr:GetLifecyclePolicy", "ecr:PutLifecyclePolicy", "ecr:DeleteLifecyclePolicy",
          "ecr:PutImageTagMutability", "ecr:PutImageScanningConfiguration",
          "ecr:TagResource", "ecr:UntagResource", "ecr:ListTagsForResource",
          "ecr:DescribeImages", "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload", "ecr:PutImage",
          "ecr:GetRegistryScanningConfiguration", "ecr:DescribeRegistry", "ecr:PutEncryptionConfiguration"
        ]
        Resource = "arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/${var.name}-*"
      },
      {
        Sid      = "STSCallerIdentity"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# Policy 2 — state, logging, and ancillary services
resource "aws_iam_policy" "github_actions_services" {
  name        = "${var.name}-github-actions-services-policy"
  description = "GitHub Actions: state backend and ancillary service management"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Manage"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket",
          "s3:GetBucketPolicy", "s3:PutBucketPolicy", "s3:DeleteBucketPolicy",
          "s3:GetBucketVersioning", "s3:PutBucketVersioning",
          "s3:GetEncryptionConfiguration", "s3:PutEncryptionConfiguration",
          "s3:GetBucketPublicAccessBlock", "s3:PutBucketPublicAccessBlock",
          "s3:GetLifecycleConfiguration", "s3:PutLifecycleConfiguration",
          "s3:CreateBucket", "s3:DeleteBucket",
          "s3:GetBucketAcl", "s3:PutBucketAcl",
          "s3:GetBucketLogging", "s3:PutBucketLogging",
          "s3:GetBucketTagging", "s3:PutBucketTagging"
        ]
        Resource = [
          "arn:aws:s3:::${var.terraform_state_bucket}",
          "arn:aws:s3:::${var.terraform_state_bucket}/*",
          "arn:aws:s3:::${var.name}-*",
          "arn:aws:s3:::${var.name}-*/*"
        ]
      },
      {
        Sid    = "LogsManage"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy",
          "logs:AssociateKmsKey", "logs:DisassociateKmsKey",
          "logs:ListTagsLogGroup", "logs:ListTagsForResource",
          "logs:TagLogGroup", "logs:UntagLogGroup", "logs:TagResource", "logs:UntagResource",
          "logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents", "logs:GetLogEvents"
        ]
        Resource = "*"
      },
      {
        Sid      = "SSMManage"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath",
                    "ssm:DescribeParameters", "ssm:PutParameter", "ssm:DeleteParameter",
                    "ssm:AddTagsToResource", "ssm:ListTagsForResource"]
        Resource = "*"
      },
      {
        Sid    = "SecretsManage"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret", "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue", "secretsmanager:UpdateSecret",
          "secretsmanager:GetResourcePolicy", "secretsmanager:PutResourcePolicy",
          "secretsmanager:DeleteResourcePolicy", "secretsmanager:TagResource",
          "secretsmanager:UntagResource", "secretsmanager:ListSecrets",
          "secretsmanager:ListSecretVersionIds", "secretsmanager:RestoreSecret",
          "secretsmanager:RotateSecret", "secretsmanager:CancelRotateSecret",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = "arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:${var.name}/*"
      },
      {
        Sid    = "SNSManage"
        Effect = "Allow"
        Action = ["sns:CreateTopic", "sns:DeleteTopic", "sns:GetTopicAttributes",
                  "sns:SetTopicAttributes", "sns:Subscribe", "sns:Unsubscribe",
                  "sns:ListSubscriptionsByTopic", "sns:GetSubscriptionAttributes",
                  "sns:TagResource", "sns:UntagResource", "sns:ListTagsForResource"]
        Resource = "arn:aws:sns:*:${data.aws_caller_identity.current.account_id}:${var.name}-*"
      },
      {
        Sid    = "CloudTrailManage"
        Effect = "Allow"
        Action = ["cloudtrail:CreateTrail", "cloudtrail:DeleteTrail", "cloudtrail:GetTrail",
                  "cloudtrail:GetTrailStatus", "cloudtrail:UpdateTrail",
                  "cloudtrail:StartLogging", "cloudtrail:StopLogging",
                  "cloudtrail:GetEventSelectors", "cloudtrail:PutEventSelectors",
                  "cloudtrail:ListTags", "cloudtrail:AddTags", "cloudtrail:RemoveTags",
                  "cloudtrail:DescribeTrails"]
        Resource = "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/${var.name}-*"
      },
      {
        Sid    = "EventBridgeManage"
        Effect = "Allow"
        Action = ["events:PutRule", "events:DeleteRule", "events:DescribeRule",
                  "events:EnableRule", "events:DisableRule",
                  "events:PutTargets", "events:RemoveTargets", "events:ListTargetsByRule",
                  "events:TagResource", "events:UntagResource", "events:ListTagsForResource"]
        Resource = "arn:aws:events:*:${data.aws_caller_identity.current.account_id}:rule/${var.name}-*"
      },
      {
        Sid    = "AccessAnalyzerManage"
        Effect = "Allow"
        Action = ["access-analyzer:CreateAnalyzer", "access-analyzer:DeleteAnalyzer",
                  "access-analyzer:GetAnalyzer", "access-analyzer:UpdateAnalyzer",
                  "access-analyzer:TagResource", "access-analyzer:UntagResource",
                  "access-analyzer:ListTagsForResource", "access-analyzer:ListAnalyzers"]
        Resource = "arn:aws:access-analyzer:*:${data.aws_caller_identity.current.account_id}:analyzer/${var.name}-*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}

resource "aws_iam_role_policy_attachment" "github_actions_services" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_services.arn
}

# ECR Repository
resource "aws_ecr_repository" "app" {
  name                 = "${var.name}-app"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.ecr_kms_key_arn
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images older than 7 days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 7
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_repository_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowAccountPull"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action = [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ]
    }]
  })
}
