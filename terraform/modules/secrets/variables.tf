variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for secrets encryption"
  type        = string
}

variable "recovery_window_in_days" {
  description = "Number of days before secret is permanently deleted"
  type        = number
  default     = 30
}

variable "enable_rotation" {
  description = "Enable automatic secret rotation"
  type        = bool
  default     = false
}

variable "rotation_lambda_arn" {
  description = "ARN of Lambda function for secret rotation"
  type        = string
  default     = ""
}

variable "irsa_role_arns" {
  description = "List of IRSA role ARNs allowed to access secrets"
  type        = list(string)
  default     = []
}

variable "ssm_parameters" {
  description = "Map of SSM parameters to create"
  type = map(object({
    value       = string
    description = string
    sensitive   = bool
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
