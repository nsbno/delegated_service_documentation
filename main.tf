provider "aws" {
  # Module expects aws.certificate_provider set to us-east-1 to be passed in via the "providers" argument
  alias  = "useast"
  region = "us-east-1"
}

data "aws_route53_zone" "main" {
  name = var.hosted_zone_name
}

resource "aws_route53_record" "wwww_a" {
  name    = "${var.site_name}."
  type    = "CNAME"
  ttl     = "300"
  records = ["stasjon.vydev.io"]

  zone_id = data.aws_route53_zone.main.id
}

data "aws_caller_identity" "this" {}
data "aws_region" "this" {}
data "aws_organizations_organization" "this" {}

locals {
  current_account_id      = data.aws_caller_identity.this.account_id
  current_region          = data.aws_region.this.name
  current_organization_id = data.aws_organizations_organization.this.id
}

resource "aws_s3_bucket" "staging" {
  bucket = var.staging_bucket_name == "" ? "${local.current_account_id}-${var.name_prefix}-delegated-service-documentation" : var.staging_bucket_name
  tags = var.tags
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

resource "aws_s3_bucket_policy" "s3_to_external_accounts" {
  bucket = aws_s3_bucket.staging.id
  policy = data.aws_iam_policy_document.s3_for_external_accounts.json
}

resource "aws_s3_bucket" "verified" {
  bucket = var.verified_bucket_name == "" ? "${local.current_account_id}-${var.name_prefix}-service-documentation" : var.verified_bucket_name
  tags = var.tags
}

resource "aws_s3_bucket_ownership_controls" "verified" {
  bucket = aws_s3_bucket.verified.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
