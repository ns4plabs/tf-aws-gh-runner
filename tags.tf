# resource "aws_iam_role_policy" "tags" {
#   for_each = module.runners

#   name = "tf-aws-gh-runner-${each.key}"
#   role = each.value.runners.role_runner.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid = "AllowLimitedPut"
#         Action = [
#           "ec2:CreateTags",
#         ]
#         Effect   = "Allow"
#         Resource = [
#           "arn:aws:ec2:*:*:instance/*"
#         ]
#         Condition = {
#           ArnEquals: {
#             "ec2:SourceInstanceARN": "$${aws:ResourceArn}"
#           }
#         }
#       },
#     ]
#   })
# }
