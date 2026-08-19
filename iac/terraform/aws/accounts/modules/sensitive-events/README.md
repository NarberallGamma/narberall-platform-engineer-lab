# Sensitive API call fan-in

Private delivery used one EventBridge + SNS pair per account/region (eleven aliases). This module keeps the pattern: CloudTrail `eventName` filters for IAM, S3, and EC2, then HTTPS to AWS Chatbot SNS.

Aliases are generic (`staging_eu_central_1`, `prod_ap_southeast_1`). ARNs use `000000000000`.
