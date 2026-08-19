resource "aws_cloudwatch_event_rule" "staging_ec2" {
  provider       = aws.staging_eu_central_1
  event_bus_name = "default"
  event_pattern  = local.ec2_event_pattern
}

resource "aws_cloudwatch_event_target" "staging_ec2" {
  provider = aws.staging_eu_central_1
  rule     = aws_cloudwatch_event_rule.staging_ec2.name
  arn      = aws_sns_topic.sensitive_api_calls.arn
  role_arn = aws_iam_role.sensitive_api_calls.arn
}

resource "aws_cloudwatch_event_rule" "staging_s3" {
  provider       = aws.staging_eu_central_1
  event_bus_name = "default"
  event_pattern  = local.s3_event_pattern
}

resource "aws_cloudwatch_event_target" "staging_s3" {
  provider = aws.staging_eu_central_1
  rule     = aws_cloudwatch_event_rule.staging_s3.name
  arn      = aws_sns_topic.sensitive_api_calls.arn
  role_arn = aws_iam_role.sensitive_api_calls.arn
}

resource "aws_cloudwatch_event_rule" "staging_iam" {
  provider       = aws.staging_eu_central_1
  event_bus_name = "default"
  event_pattern  = local.iam_event_pattern
}

resource "aws_cloudwatch_event_target" "staging_iam" {
  provider = aws.staging_eu_central_1
  rule     = aws_cloudwatch_event_rule.staging_iam.name
  arn      = aws_sns_topic.sensitive_api_calls.arn
  role_arn = aws_iam_role.sensitive_api_calls.arn
}

resource "aws_cloudwatch_event_rule" "prod_ec2" {
  provider       = aws.prod_ap_southeast_1
  event_bus_name = "default"
  event_pattern  = local.ec2_event_pattern
}

resource "aws_cloudwatch_event_target" "prod_ec2" {
  provider = aws.prod_ap_southeast_1
  rule     = aws_cloudwatch_event_rule.prod_ec2.name
  arn      = aws_sns_topic.prod_sensitive_api_calls.arn
  role_arn = aws_iam_role.prod_sensitive_api_calls.arn
}

resource "aws_cloudwatch_event_rule" "prod_s3" {
  provider       = aws.prod_ap_southeast_1
  event_bus_name = "default"
  event_pattern  = local.s3_event_pattern
}

resource "aws_cloudwatch_event_target" "prod_s3" {
  provider = aws.prod_ap_southeast_1
  rule     = aws_cloudwatch_event_rule.prod_s3.name
  arn      = aws_sns_topic.prod_sensitive_api_calls.arn
  role_arn = aws_iam_role.prod_sensitive_api_calls.arn
}

resource "aws_cloudwatch_event_rule" "prod_iam" {
  provider       = aws.prod_ap_southeast_1
  event_bus_name = "default"
  event_pattern  = local.iam_event_pattern
}

resource "aws_cloudwatch_event_target" "prod_iam" {
  provider = aws.prod_ap_southeast_1
  rule     = aws_cloudwatch_event_rule.prod_iam.name
  arn      = aws_sns_topic.prod_sensitive_api_calls.arn
  role_arn = aws_iam_role.prod_sensitive_api_calls.arn
}
