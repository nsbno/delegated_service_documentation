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
      "s3:GetObject*",
      "s3:DeleteObject*"
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

data "aws_iam_policy_document" "s3_cloudfront" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.verified.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.verified.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }

  statement {
    actions   = [
                "s3:PutObjectAcl*",
                "s3:PutObject*",
                "s3:GetObject*"
            ]
    resources = [
                "${aws_s3_bucket.verified.arn}/*",
                "${aws_s3_bucket.verified.arn}"
           ]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.source_account}:root"]
     }
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject*",
      "s3:PutObjectAcl*",
      "s3:GetObject*",
      "s3:DeleteObject*"
    ]
    resources = ["${aws_s3_bucket.verified.arn}/json/*"]
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

data "aws_iam_policy_document" "s3_policy" {
  version = "2012-10-17"

  statement {
    effect = "Allow"
    actions = [
            "s3:PutObject",
            "s3:PutObjectAcl*",
            "s3:List*"
    ]
    resources = [
                "${aws_s3_bucket.verified.arn}/*",
                "${aws_s3_bucket.verified.arn}"
           ]
  }
}

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
  }
}
