locals {
  alarm_actions = [aws_sns_topic.alarms.arn]
  db_enabled    = var.db_instance_identifier != ""
  alb_enabled   = var.load_balancer_arn_suffix != ""
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5xx" {
  count = local.alb_enabled ? 1 : 0

  alarm_name          = "${var.name}-alb-target-5xx"
  alarm_description   = "Backend is returning server errors through the ingress load balancer."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.alb_5xx_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = { LoadBalancer = var.load_balancer_arn_suffix }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  count = local.alb_enabled ? 1 : 0

  alarm_name          = "${var.name}-alb-latency"
  alarm_description   = "Backend p90 response time is above the service objective."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p90"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.alb_latency_threshold_seconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = { LoadBalancer = var.load_balancer_arn_suffix }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = var.tags
}

# No healthy targets means the service is down, independent of error rate.
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  count = local.alb_enabled ? 1 : 0

  alarm_name          = "${var.name}-alb-no-healthy-hosts"
  alarm_description   = "The ingress load balancer has no healthy targets."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  dimensions = { LoadBalancer = var.load_balancer_arn_suffix }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "db_cpu" {
  count = local.db_enabled ? 1 : 0

  alarm_name          = "${var.name}-db-cpu"
  alarm_description   = "Database CPU is sustained near capacity."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  dimensions = { DBInstanceIdentifier = var.db_instance_identifier }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "db_free_storage" {
  count = local.db_enabled ? 1 : 0

  alarm_name          = "${var.name}-db-free-storage"
  alarm_description   = "Database free storage is running out."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.db_free_storage_bytes_threshold
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "missing"

  dimensions = { DBInstanceIdentifier = var.db_instance_identifier }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = var.tags
}

# Connection exhaustion surfaces as application errors that look unrelated to the
# database, so it is worth alarming on directly.
resource "aws_cloudwatch_metric_alarm" "db_connections" {
  count = local.db_enabled ? 1 : 0

  alarm_name          = "${var.name}-db-connections"
  alarm_description   = "Database connection count is approaching the instance limit."
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = floor(var.db_max_connections * 0.8)
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  dimensions = { DBInstanceIdentifier = var.db_instance_identifier }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = var.tags
}
