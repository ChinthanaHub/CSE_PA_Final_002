variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform remote state"
  type        = string
}

variable "terraform_lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
}

variable "ecr_kms_key_arn" {
  description = "KMS key ARN for ECR encryption"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
