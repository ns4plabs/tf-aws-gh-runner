// It would be even better if we could create these policies on demand
// before booting up a new runner and have them limited to runner ID prefix,
// but for that we would need to modify the scale up lambda function
// which is beyond the scope for now.
resource "aws_iam_role_policy" "artifacts_v2" {
  for_each = local.runners

  name = "tf-aws-gh-runner-${each.key}"
  role = each.value.role_runner_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowLimitedGetPut"
        Action = [
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:PutObject",
          "s3:PutObjectAcl",
        ]
        Effect   = "Allow"
        Resource = ["${data.aws_s3_bucket.tf-aws-gh-runner.arn}/${each.key}/*"]
      },
      {
        Sid = "AllowLimitedList"
        Action = [
          "s3:ListBucket",
        ]
        Effect   = "Allow"
        Resource = ["${data.aws_s3_bucket.tf-aws-gh-runner.arn}"]
        Condition = {
          StringLike: {
            "s3:prefix" = [
              "${each.key}/*",
            ]
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "artifacts" {
  for_each = local.legacy_runners

  name = "tf-aws-gh-runner-${each.key}"
  role = each.value.role_runner_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowLimitedGetPut"
        Action = [
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:PutObject",
          "s3:PutObjectAcl",
        ]
        Effect   = "Allow"
        Resource = ["${data.aws_s3_bucket.tf-aws-gh-runner.arn}/${each.key}/*"]
      },
      {
        Sid = "AllowLimitedList"
        Action = [
          "s3:ListBucket",
        ]
        Effect   = "Allow"
        Resource = ["${data.aws_s3_bucket.tf-aws-gh-runner.arn}"]
        Condition = {
          StringLike: {
            "s3:prefix" = [
              "${each.key}/*",
            ]
          }
        }
      },
    ]
  })
}
