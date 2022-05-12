provider "aws" {
  # Module expects aws.certificate_provider set to us-east-1 to be passed in via the "providers" argument
  alias   = "useast"
  region  = "us-east-1"
}

data "aws_caller_identity" "this" {}
data "aws_region" "this" {}
data "aws_organizations_organization" "this" {}

locals {
  current_account_id      = data.aws_caller_identity.this.account_id
  current_region          = data.aws_region.this.name
  current_organization_id = data.aws_organizations_organization.this.id
}

###################################################
#                                                 #
# Bucket with Service Documentation               #
#                                                 #
###################################################

resource "aws_s3_bucket" "verified" {
  bucket = var.verified_bucket_name == "" ? "${local.current_account_id}-${var.name_prefix}-service-documentation" : var.verified_bucket_name
  tags = var.tags
}

resource "aws_s3_bucket" "authbucket" {
  bucket = var.verified_bucket_name == "" ? "${local.current_account_id}-${var.name_prefix}-service-documentation-public" : var.verified_bucket_name
  tags = var.tags
}

data "aws_route53_zone" "main" {
  name = var.hosted_zone_name
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "origin access identity for s3/cloudfront"
}

resource "aws_acm_certificate" "cert_website" {
  domain_name       = var.site_name
  validation_method = "DNS"
  provider          = aws.useast
  tags              = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_website_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert_website.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.id
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.cert_website.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_website_validation : record.fqdn]
  provider                = aws.useast
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [
    aws_acm_certificate_validation.main,
  ]

  origin {
    domain_name = aws_s3_bucket.verified.bucket_regional_domain_name
    origin_id   = aws_cloudfront_origin_access_identity.origin_access_identity.id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  origin {
    domain_name = aws_s3_bucket.authbucket.bucket_regional_domain_name
    origin_id   = "public"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
  
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [aws_acm_certificate.cert_website.domain_name]

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  default_cache_behavior {
    allowed_methods = [
      "GET",
      "HEAD",
    ]

    cached_methods = [
      "GET",
      "HEAD",
    ]

    target_origin_id = "public"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
	
	lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.basic_auth.qualified_arn
      include_body = false
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  price_class = "PriceClass_100"

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert_website.arn
    ssl_support_method  = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_route53_record" "wwww_a" {
  name    = "${var.site_name}."
  type    = "A"
  zone_id = data.aws_route53_zone.main.id

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_s3_bucket_policy" "s3_to_cloudfront" {
  bucket = aws_s3_bucket.verified.id
  policy = data.aws_iam_policy_document.s3_cloudfront.json
}

resource "aws_s3_bucket_policy" "s3_to_cloudfront_authbucket" {
  bucket = aws_s3_bucket.authbucket.id
  policy = data.aws_iam_policy_document.s3_cloudfront_public.json
}

###################################################
#                                                 #
# Staging Bucket for Unverified                   #
# Service Documentation                           #
###################################################
resource "aws_s3_bucket" "staging" {
  bucket = var.staging_bucket_name == "" ? "${local.current_account_id}-${var.name_prefix}-delegated-service-documentation" : var.staging_bucket_name
  tags = var.tags
}

resource "aws_s3_bucket_policy" "s3_to_external_accounts" {
  bucket = aws_s3_bucket.staging.id
  policy = data.aws_iam_policy_document.s3_for_external_accounts.json
}

resource "aws_s3_bucket_notification" "this" {
  bucket = aws_s3_bucket.staging.id

queue {
    id            = "servicedoc"
    queue_arn     = aws_sqs_queue.service_doc.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".json"
  }
}

resource "aws_sqs_queue" "service_doc" {
  name                        = "${var.name_prefix}-delegated-service-documentation"
  tags                        = var.tags

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sqs_dead_letter_queue.arn
    maxReceiveCount     = var.maxReceiveCount
  })
  
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "arn:aws:sqs:*:*:*-delegated-service-documentation",
      "Condition": {
        "ArnEquals": { "aws:SourceArn": "${aws_s3_bucket.staging.arn}" }
      }
    }
  ]
}
POLICY
}

resource "aws_sqs_queue" "sqs_dead_letter_queue" {
  name                      = "${var.name_prefix}-dead-letters-queue"
  message_retention_seconds = var.message_retention_seconds

  tags                        = var.tags
}

###################################################
#                                                 #
# CircleCIupdate                                  #
#                                                 #
###################################################
resource "aws_iam_user" "portal_content" {
  name          = "${var.name_prefix}-portal-content"
  force_destroy = "true"
}

resource "aws_iam_policy" "s3_write" {
  name_prefix = "${var.name_prefix}-updateportal-content"
  description = "Policy that grants access to update portal"
  policy      = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_iam_user_policy_attachment" "s3_write_to_circleci" {
  user       = aws_iam_user.portal_content.name
  policy_arn = aws_iam_policy.s3_write.arn
}

###################################################
#                                                 #
# autobuild of antora                             #
#                                                 #
###################################################
resource "aws_lambda_event_source_mapping" "new_service" {
  event_source_arn = aws_sqs_queue.service_doc.arn
  function_name    = aws_lambda_function.build_antora_site.arn
}

data "archive_file" "build_antora_site" {
  type        = "zip"
  source_file = "${path.module}/src/build-antora-site/build-antora-site.py"
  output_path = "${path.module}/src/build-antora-site/build-antora-site.zip"
}

resource "aws_lambda_function" "build_antora_site" {
  filename         = data.archive_file.build_antora_site.output_path
  source_code_hash = filebase64sha256(data.archive_file.build_antora_site.output_path)
  function_name    = "${var.name_prefix}-build-antora-site"
  handler          = "build-antora-site.lambda_handler"
  role             = aws_iam_role.build_antora_site_lamda_role.arn
  runtime          = "python3.8"
  timeout          = "25"
  environment {
    variables = {
      ecs_cluster = aws_ecs_cluster.cluster.arn
      fargate_lambda_name = var.fargate_lambda_name
      image = var.image
      subnets = var.subnets
      task_execution_role_arn = aws_iam_role.antora_task_execution_role.arn
      task_role_arn = aws_iam_role.fargate_task.arn
    }
  }
}

resource "aws_iam_role" "build_antora_site_lamda_role" {
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "build_antora_site_permsissions" {
  name   = "${var.name_prefix}-get-antora-files"
  policy = data.aws_iam_policy_document.build_antora_site_permissions.json
  role   = aws_iam_role.build_antora_site_lamda_role.id
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "build_antora_site_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
      "cloudwatch:PutMetricData",
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:GetQueueAttributes",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
    ]
    resources = [aws_sqs_queue.service_doc.arn]
  }
  statement {
    effect = "Allow"
    actions = [
                "s3:Get*",
                "s3:List*"
    ]
    resources =  [
                "${aws_s3_bucket.staging.arn}/*",
                "${aws_s3_bucket.staging.arn}",
                "${aws_s3_bucket.verified.arn}/*",
                "${aws_s3_bucket.verified.arn}"
           ]
  }
  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
    ]
    resources = ["arn:aws:lambda:eu-west-1:${local.current_account_id}:function:${var.fargate_lambda_name}"]
  }
}

###################################################
#                                                 #
# Fargate run single task                         #
#                                                 #
###################################################

module "single_use_fargate_task" {
  source      = "github.com/nsbno/terraform-aws-single-use-fargate-task?ref=78e9578"
  name_prefix = "${var.name_prefix}-antora"
  tags        = var.tags
}

###################################################
#                                                 #
# ECS cluster                                     #
#                                                 #
###################################################

resource "aws_ecs_cluster" "cluster" {
  name = "${var.name_prefix}-antora-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_iam_role" "antora_task_execution_role" {
  name               = "${var.name_prefix}-antora-TaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "TaskExecution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.antora_task_execution_role.id
}

resource "aws_iam_role_policy_attachment" "cloudwatchexecrole" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
  role       = aws_iam_role.antora_task_execution_role.id
}

resource "aws_iam_role" "fargate_task" {
  name               = "${var.name_prefix}-single-use-tasks"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "cloudwatchtask" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
  role       = aws_iam_role.fargate_task.id
}

resource "aws_iam_role_policy_attachment" "ssmaccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
  role       = aws_iam_role.fargate_task.id
}

###################################################
#                                                 #
# Lambda EDGE for Auth                            #
#                                                 #
###################################################

data "archive_file" "basic_auth_function" {
  type        = "zip"
  source_file = "${path.module}/src/lambdaedge/lambdaedge.js"
  output_path = "${path.module}/src/lambdaedge/lambdaedge.zip"
}

resource "aws_lambda_function" "basic_auth" {
  filename         = data.archive_file.basic_auth_function.output_path
  function_name    = "${var.name_prefix}-basic_auth"
  role             = aws_iam_role.lambdaedge.arn
  handler          = "lambdaedge.handler"
  source_code_hash = filebase64sha256(data.archive_file.basic_auth_function.output_path)
  runtime          = "nodejs12.x"
  description      = "Protect CloudFront distributions with Basic Authentication"
  publish          = true
  provider         = aws.useast
}

resource "aws_iam_role" "lambdaedge" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com",
          "edgelambda.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda" {
  role = "${aws_iam_role.lambdaedge.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambdassm" {
  role = "${aws_iam_role.lambdaedge.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:DescribeParameters",
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
