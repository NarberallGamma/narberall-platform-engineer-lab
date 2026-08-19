data "aws_iam_policy_document" "put_events" {
  statement {
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = ["arn:aws:events:eu-central-1:000000000000:event-bus/default"]
  }
}

data "aws_iam_policy_document" "events_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "sensitive_api_calls" {
  provider = aws.staging_eu_central_1
  name     = "sensitive-api-calls"
  policy   = data.aws_iam_policy_document.put_events.json
}

resource "aws_iam_role" "sensitive_api_calls" {
  provider           = aws.staging_eu_central_1
  name               = "sensitive-api-calls"
  assume_role_policy = data.aws_iam_policy_document.events_assume.json
}

resource "aws_iam_role_policy_attachment" "sensitive_api_calls" {
  provider   = aws.staging_eu_central_1
  role       = aws_iam_role.sensitive_api_calls.name
  policy_arn = aws_iam_policy.sensitive_api_calls.arn
}

resource "aws_sns_topic" "sensitive_api_calls" {
  provider = aws.staging_eu_central_1
  name     = "sensitive-api-calls"
}

resource "aws_sns_topic_subscription" "sensitive_api_calls" {
  provider  = aws.staging_eu_central_1
  topic_arn = aws_sns_topic.sensitive_api_calls.arn
  protocol  = "https"
  endpoint  = "https://global.sns-api.chatbot.amazonaws.com"
}

resource "aws_iam_policy" "prod_sensitive_api_calls" {
  provider = aws.prod_ap_southeast_1
  name     = "sensitive-api-calls"
  policy   = data.aws_iam_policy_document.put_events.json
}

resource "aws_iam_role" "prod_sensitive_api_calls" {
  provider           = aws.prod_ap_southeast_1
  name               = "sensitive-api-calls"
  assume_role_policy = data.aws_iam_policy_document.events_assume.json
}

resource "aws_iam_role_policy_attachment" "prod_sensitive_api_calls" {
  provider   = aws.prod_ap_southeast_1
  role       = aws_iam_role.prod_sensitive_api_calls.name
  policy_arn = aws_iam_policy.prod_sensitive_api_calls.arn
}

resource "aws_sns_topic" "prod_sensitive_api_calls" {
  provider = aws.prod_ap_southeast_1
  name     = "sensitive-api-calls"
}

resource "aws_sns_topic_subscription" "prod_sensitive_api_calls" {
  provider  = aws.prod_ap_southeast_1
  topic_arn = aws_sns_topic.prod_sensitive_api_calls.arn
  protocol  = "https"
  endpoint  = "https://global.sns-api.chatbot.amazonaws.com"
}
