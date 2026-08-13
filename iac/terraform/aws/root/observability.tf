resource "aws_sns_topic" "alerts" {
  name = "project-a-alerts"
}

resource "aws_cloudwatch_event_rule" "guardduty" {
  name        = "project-a-guardduty"
  description = "Forward GuardDuty findings"
  event_pattern = jsonencode({
    source = ["aws.guardduty"]
  })
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule = aws_cloudwatch_event_rule.guardduty.name
  arn  = aws_sns_topic.alerts.arn
}

resource "aws_dlm_lifecycle_policy" "ebs_backup" {
  description        = "project-a daily EBS snapshots"
  execution_role_arn = aws_iam_role.dlm.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]
    schedule {
      name = "daily"
      create_rule { interval = 24; interval_unit = "HOURS"; times = ["03:00"] }
      retain_rule { count = 7 }
      copy_tags = true
    }
    target_tags = { Backup = "true" }
  }
}

resource "aws_iam_role" "dlm" {
  name = "project-a-dlm"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "dlm.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
