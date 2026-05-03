output "eks_kms_key_arn" {
  description = "KMS key ARN for EKS secrets"
  value       = aws_kms_key.eks.arn
}

output "eks_kms_key_id" {
  description = "KMS key ID for EKS secrets"
  value       = aws_kms_key.eks.key_id
}

output "cloudwatch_kms_key_arn" {
  description = "KMS key ARN for CloudWatch Logs"
  value       = aws_kms_key.cloudwatch.arn
}

output "s3_kms_key_arn" {
  description = "KMS key ARN for S3 buckets"
  value       = aws_kms_key.s3.arn
}

output "secrets_kms_key_arn" {
  description = "KMS key ARN for Secrets Manager"
  value       = aws_kms_key.secrets.arn
}
