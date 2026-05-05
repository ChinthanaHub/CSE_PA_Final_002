output "external_secrets_role_arn" {
  description = "IRSA role ARN for External Secrets Operator"
  value       = aws_iam_role.external_secrets.arn
}

output "load_balancer_controller_role_arn" {
  description = "IRSA role ARN for AWS Load Balancer Controller"
  value       = aws_iam_role.load_balancer_controller.arn
}

