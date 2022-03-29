data "aws_iam_policy_document" "sqs_for_s3" {
  statement {
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = [
      "sqs:SendMessage",
    ]
    resources = [aws_sqs_queue.this.arn]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.staging.arn]
    }
  }
}

data "aws_iam_policy_document" "sqs_for_forwarder" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
    ]
    resources = [aws_sqs_queue.this.arn]
  }
}

data "aws_iam_policy_document" "sqs_access" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
    ]
    resources = [
      aws_sqs_queue.this.arn
    ]
  }
}

data "aws_iam_policy_document" "s3_for_external_accounts" {
  statement {
    effect  = "Allow"
    actions = ["s3:List*"]
    resources = [
      aws_s3_bucket.staging.arn,
      "${aws_s3_bucket.staging.arn}/*"
    ]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values = [
        local.current_organization_id
      ]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject*",
      "s3:PutObjectAcl*",
      "s3:GetObject*"
    ]
    resources = formatlist("${aws_s3_bucket.staging.arn}/%s/$${aws:PrincipalAccount}/*", ["dev", "test", "stage", "prod"])
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values = [
        local.current_organization_id
      ]
    }
  }
}


data "aws_iam_policy_document" "s3_for_internal_accounts" {
  statement {
    effect    = "Allow"
    actions   = ["s3:Get*", "s3:List*"]
    resources = [aws_s3_bucket.verified.arn, "${aws_s3_bucket.verified.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values = [
        local.current_organization_id
      ]
    }
  }
}
