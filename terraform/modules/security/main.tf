terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# GuardDuty
resource "aws_guardduty_detector" "main" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_guardduty_publishing_destination" "s3" {
  count           = var.enable_guardduty && var.findings_bucket_arn != "" ? 1 : 0
  detector_id     = aws_guardduty_detector.main[0].id
  destination_arn = var.findings_bucket_arn
  kms_key_arn     = var.kms_key_arn

  destination_type = "S3"
}

resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  count       = var.enable_guardduty ? 1 : 0
  name        = "${var.name}-guardduty-findings"
  description = "Capture GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  count     = var.enable_guardduty ? 1 : 0
  rule      = aws_cloudwatch_event_rule.guardduty_findings[0].name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arn

  input_transformer {
    input_paths = {
      severity    = "$.detail.severity"
      type        = "$.detail.type"
      description = "$.detail.description"
      region      = "$.region"
      account     = "$.account"
    }
    input_template = "\"GuardDuty Finding: <type>\\nSeverity: <severity>\\nRegion: <region>\\nAccount: <account>\\nDescription: <description>\""
  }
}

# Security Hub
resource "aws_securityhub_account" "main" {
  count = var.enable_securityhub ? 1 : 0
}

resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.enable_securityhub ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"
}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  count         = var.enable_securityhub ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

resource "aws_securityhub_standards_subscription" "pci_dss" {
  count         = var.enable_securityhub ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/pci-dss/v/3.2.1"
}

resource "aws_securityhub_product_subscription" "guardduty" {
  count       = var.enable_securityhub && var.enable_guardduty ? 1 : 0
  depends_on  = [aws_securityhub_account.main]
  product_arn = "arn:aws:securityhub:${data.aws_region.current.name}::product/aws/guardduty"
}

resource "aws_cloudwatch_event_rule" "securityhub_findings" {
  count       = var.enable_securityhub ? 1 : 0
  name        = "${var.name}-securityhub-high-findings"
  description = "Capture Security Hub HIGH/CRITICAL findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
        Workflow = {
          Status = ["NEW"]
        }
      }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "securityhub_sns" {
  count     = var.enable_securityhub ? 1 : 0
  rule      = aws_cloudwatch_event_rule.securityhub_findings[0].name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arn
}

# IAM Access Analyzer
resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "${var.name}-access-analyzer"
  type          = "ACCOUNT"
  tags          = var.tags
}

resource "aws_cloudwatch_event_rule" "access_analyzer" {
  name        = "${var.name}-access-analyzer-findings"
  description = "Capture IAM Access Analyzer findings"

  event_pattern = jsonencode({
    source      = ["aws.access-analyzer"]
    detail-type = ["Access Analyzer Finding"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "access_analyzer_sns" {
  rule      = aws_cloudwatch_event_rule.access_analyzer.name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arn
}

# Config Rules for compliance
resource "aws_config_configuration_recorder" "main" {
  count    = var.enable_config ? 1 : 0
  name     = "${var.name}-config-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_iam_role" "config" {
  count = var.enable_config ? 1 : 0
  name  = "${var.name}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enable_config ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# SNS policy allowing security services to publish
resource "aws_sns_topic_policy" "security_alerts" {
  arn = var.sns_topic_arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowAWSServicesToPublish"
      Effect = "Allow"
      Principal = {
        Service = [
          "events.amazonaws.com",
          "guardduty.amazonaws.com",
          "securityhub.amazonaws.com"
        ]
      }
      Action   = "SNS:Publish"
      Resource = var.sns_topic_arn
    }]
  })
}
