variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for GuardDuty findings encryption"
  type        = string
  default     = ""
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for security notifications"
  type        = string
}

variable "findings_bucket_arn" {
  description = "S3 bucket ARN for GuardDuty findings export"
  type        = string
  default     = ""
}

variable "enable_guardduty" {
  description = "Enable GuardDuty detector (requires account subscription)"
  type        = bool
  default     = false
}

variable "enable_securityhub" {
  description = "Enable Security Hub (requires account subscription)"
  type        = bool
  default     = false
}

variable "enable_config" {
  description = "Enable AWS Config recorder"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
