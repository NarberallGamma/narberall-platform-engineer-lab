locals {
  iam_event_pattern = jsonencode({
    detail = {
      eventName = [
        "AttachGroupPolicy",
        "AttachRolePolicy",
        "AttachUserPolicy",
        "CreateAccessKey",
        "CreatePolicy",
        "CreatePolicyVersion",
        "CreateRole",
        "CreateUser",
        "DeactivateMFADevice",
        "DeleteAccountPasswordPolicy",
        "DetachRolePolicy",
        "PutRolePolicy",
        "PutUserPolicy",
        "UpdateAccessKey",
        "UpdateAssumeRolePolicy",
        "UploadSSHPublicKey",
      ]
      eventSource = ["iam.amazonaws.com"]
    }
    detail-type = ["AWS API Call via CloudTrail"]
    source      = ["aws.iam"]
  })

  s3_event_pattern = jsonencode({
    detail = {
      eventName = [
        "DeleteBucket",
        "DeleteBucketPolicy",
        "DeletePublicAccessBlock",
        "PutBucketAcl",
        "PutBucketPolicy",
        "PutPublicAccessBlock",
      ]
      eventSource = ["s3.amazonaws.com"]
    }
    detail-type = ["AWS API Call via CloudTrail"]
    source      = ["aws.s3"]
  })

  ec2_event_pattern = jsonencode({
    detail = {
      eventName = [
        "StopInstances",
        "TerminateInstances",
        "CreateKeyPair",
        "ImportKeyPair",
        "AuthorizeSecurityGroupIngress",
        "CreateSecurityGroup",
        "DeleteSecurityGroup",
      ]
      eventSource = ["ec2.amazonaws.com"]
    }
    detail-type = ["AWS API Call via CloudTrail"]
    source      = ["aws.ec2"]
  })
}
