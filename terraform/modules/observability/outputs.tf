output "alarm_topic_arn" {
  description = "SNS topic alarms publish to."
  value       = aws_sns_topic.alarms.arn
}

output "application_log_group_name" {
  description = "CloudWatch log group carrying container stdout."
  value       = aws_cloudwatch_log_group.application.name
}

output "cloudwatch_agent_role_arn" {
  description = "IRSA role used by the Container Insights agent."
  value       = aws_iam_role.cloudwatch_agent.arn
}
