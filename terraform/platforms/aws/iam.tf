resource "aws_iam_role" "eks_node" {
  name = "project-a-eks-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_policy" "app_s3_read" {
  name = "project-a-app-s3-read"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = ["*"]
    }]
  })
}

resource "aws_iam_user" "ci" {
  name = "project-a-ci"
}

resource "aws_iam_user_policy_attachment" "ci_s3" {
  user       = aws_iam_user.ci.name
  policy_arn = aws_iam_policy.app_s3_read.arn
}
