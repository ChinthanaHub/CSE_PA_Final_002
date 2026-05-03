terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.name}/app/secrets"
  description             = "Application secrets for ${var.name}"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    DB_PASSWORD     = "REPLACE_ME_ON_DEPLOY"
    API_KEY         = "REPLACE_ME_ON_DEPLOY"
    JWT_SECRET      = "REPLACE_ME_ON_DEPLOY"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name}/db/credentials"
  description             = "Database credentials for ${var.name}"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = "appuser"
    password = "REPLACE_ME_ON_DEPLOY"
    host     = "REPLACE_ME_ON_DEPLOY"
    port     = "5432"
    dbname   = "appdb"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_rotation" "app" {
  count               = var.enable_rotation ? 1 : 0
  secret_id           = aws_secretsmanager_secret.app.id
  rotation_lambda_arn = var.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = 30
  }
}

# SSM Parameter Store for non-sensitive configuration
resource "aws_ssm_parameter" "app_config" {
  for_each = var.ssm_parameters

  name        = "/${var.name}/${each.key}"
  type        = each.value.sensitive ? "SecureString" : "String"
  value       = each.value.value
  description = each.value.description
  key_id      = each.value.sensitive ? var.kms_key_arn : null

  tags = var.tags
}

# Resource policy to allow cross-account access if needed
resource "aws_secretsmanager_secret_policy" "app" {
  secret_arn = aws_secretsmanager_secret.app.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowEKSIRSAAccess"
      Effect = "Allow"
      Principal = {
        AWS = var.irsa_role_arns
      }
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "*"
    }]
  })
}
