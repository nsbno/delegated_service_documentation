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
# Service Documentation                           #
#                                                 #
###################################################




###################################################
#                                                 #
# Bucket with Service Documentation               #
#                                                 #
###################################################

resource "aws_s3_bucket" "verified" {
  bucket = var.verified_bucket_name == "" ? "${local.current_account_id}-${var.name_prefix}-service-documentation" : var.verified_bucket_name
  tags = var.tags
}

resource "aws_s3_bucket_policy" "s3_to_internal_accounts" {
  bucket = aws_s3_bucket.verified.id
  policy = data.aws_iam_policy_document.s3_for_internal_accounts.json
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

resource "aws_lambda_permission" "allow_s3" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forwarder.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.staging.arn
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

resource "aws_sqs_queue" "this" {
  name                        = "${var.name_prefix}-delegated-service-documentation.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  message_retention_seconds   = 1209600
  visibility_timeout_seconds  = var.lambda_timeout * 2
  tags                        = var.tags
}

resource "aws_sqs_queue" "service_doc" {
  name                        = "${var.name_prefix}-delegated-service-documentation"
  tags                        = var.tags
  
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

#######################################
#                                     #
# SQS forwarder                       #
#                                     #
#######################################
data "archive_file" "forwarder" {
  type        = "zip"
  source_file = "${path.module}/src/sqs_forwarder/main.py"
  output_path = "${path.module}/.terraform_artifacts/sqs_forwarder.zip"
}

resource "aws_lambda_function" "forwarder" {
  function_name    = "${var.name_prefix}-delegated-service-documentation-forwarder"
  role             = aws_iam_role.forwarder.arn
  handler          = "main.lambda_handler"
  runtime          = "python3.8"
  timeout          = var.lambda_timeout
  filename         = data.archive_file.forwarder.output_path
  source_code_hash = data.archive_file.forwarder.output_base64sha256
  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.this.id
    }
  }
  tags = var.tags
}

resource "aws_iam_role" "forwarder" {
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "logs_to_forwarder" {
  policy = data.aws_iam_policy_document.logs_for_forwarder.json
  role   = aws_iam_role.forwarder.id
}

resource "aws_iam_role_policy" "sqs_to_forwarder" {
  policy = data.aws_iam_policy_document.sqs_for_forwarder.json
  role   = aws_iam_role.forwarder.id
}

resource "aws_cloudwatch_log_group" "forwarder" {
  name              = "/aws/lambda/${aws_lambda_function.forwarder.function_name}"
  retention_in_days = var.lambda_log_retention_in_days
  tags              = var.tags
}

