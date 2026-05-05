locals {
  name        = "cse-pa-final-prod"
  environment = "prod"
  region      = var.aws_region

  common_tags = {
    Project     = "CSE-PA-Final"
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

module "kms" {
  source = "../../modules/kms"
  name   = local.name
  tags   = local.common_tags
}

module "vpc" {
  source = "../../modules/vpc"

  name                 = local.name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  kms_key_arn          = module.kms.cloudwatch_kms_key_arn
  tags                 = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  name                   = local.name
  github_org             = var.github_org
  github_repo            = var.github_repo
  terraform_state_bucket = "cse-pa-final-tfstate-prod"
  terraform_lock_table   = "cse-pa-final-tfstate-lock-prod"
  ecr_kms_key_arn        = module.kms.s3_kms_key_arn
  s3_kms_key_arn         = module.kms.s3_kms_key_arn
  tags                   = local.common_tags
}

module "irsa" {
  source = "../../modules/irsa"

  name                = local.name
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url
  secrets_kms_key_arn = module.kms.secrets_kms_key_arn
  tags                = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name              = "${local.name}-cluster"
  kubernetes_version        = var.kubernetes_version
  environment               = local.environment
  cluster_role_arn          = module.iam.eks_cluster_role_arn
  private_subnet_ids        = module.vpc.private_subnet_ids
  cluster_security_group_id = module.vpc.eks_cluster_security_group_id
  kms_key_arn               = module.kms.eks_kms_key_arn
  cloudwatch_kms_key_arn    = module.kms.cloudwatch_kms_key_arn
  tags                      = local.common_tags
}

module "secrets" {
  source = "../../modules/secrets"

  name                    = local.name
  kms_key_arn             = module.kms.secrets_kms_key_arn
  irsa_role_arns          = [module.irsa.external_secrets_role_arn]
  recovery_window_in_days = 30
  tags                    = local.common_tags
}

module "logging" {
  source = "../../modules/logging"

  name                   = local.name
  s3_kms_key_arn         = module.kms.s3_kms_key_arn
  cloudwatch_kms_key_arn = module.kms.cloudwatch_kms_key_arn
  sns_topic_arn          = module.logging.security_alerts_topic_arn
  alert_email            = var.alert_email
  tags                   = local.common_tags
}

module "security" {
  source = "../../modules/security"

  name          = local.name
  kms_key_arn   = module.kms.s3_kms_key_arn
  sns_topic_arn = module.logging.security_alerts_topic_arn
  enable_config = true
  tags          = local.common_tags
}

resource "aws_s3_bucket" "terraform_state" {
  bucket        = "cse-pa-final-tfstate-prod"
  force_destroy = false
  tags          = local.common_tags
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = module.kms.s3_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "cse-pa-final-tfstate-lock-prod"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = module.kms.s3_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.common_tags
}
