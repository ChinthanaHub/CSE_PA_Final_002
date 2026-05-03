variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "s3_kms_key_arn" {
  description = "KMS key ARN for S3 encryption"
  type        = string
}

variable "cloudwatch_kms_key_arn" {
  description = "KMS key ARN for CloudWatch Logs"
  type        = string
}

variable "sns_kms_key_arn" {
  description = "KMS key ARN for SNS topic"
  type        = string
  default     = ""
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for security alerts"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email address for security alert notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
