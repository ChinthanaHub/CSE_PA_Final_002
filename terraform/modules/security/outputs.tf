output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = length(aws_guardduty_detector.main) > 0 ? aws_guardduty_detector.main[0].id : null
}

output "securityhub_account_id" {
  description = "Security Hub account ID"
  value       = length(aws_securityhub_account.main) > 0 ? aws_securityhub_account.main[0].id : null
}

output "access_analyzer_arn" {
  description = "IAM Access Analyzer ARN"
  value       = aws_accessanalyzer_analyzer.main.arn
}
