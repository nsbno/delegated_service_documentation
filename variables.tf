variable "name_prefix" {
  description = "A prefix used for naming resources."
  type        = string
}

variable "state_machine_arn" {
  description = "An ARN of a deployment pipeline implemented as an AWS Step Functions state machine that the Lambda will trigger upon verified service documentationconfiguration."
  type        = string
}

variable "process_sqs_messages" {
  description = "Whether to enable or disable Lambda processing of messages from SQS. Disabling this effectively disables Delegated service documentationas no S3 events will be processed (but will remain on the queue)."
  default     = true
}

variable "verified_bucket_name" {
  description = "An optional bucket name to use when creating a bucket for holding verified service documentationconfiguration."
  default     = ""
}

variable "staging_bucket_name" {
  description = "An optional bucket name to use when creating a bucket for holding service documentationconfiguration that is yet to be verified (i.e., the \"staging\" bucket)."
  default     = ""
}

variable "trusted_accounts" {
  description = "A list AWS account IDs that are allowed to read from the S3 bucket containing verified service documentationconfiguration."
  type        = list(string)
  default     = []
}

variable "fallback_deployment_package" {
  description = "An S3 URI (e.g., `s3://<bucket>/<filename>.zip`) to a ZIP file in S3 to deploy if there are no recent executions to re-run."
  type        = string
}

variable "slack_webhook_url" {
  description = "A Slack webhook URL to send messages to."
  default     = ""
}

variable "lambda_timeout" {
  description = "The maximum number of seconds the Lambda is allowed to run."
  default     = 180
}

variable "lambda_log_retention_in_days" {
  description = "The number of days to retain CloudWatch logs associated with the Lambda functions created by the module."
  default     = 30
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = map(string)
  default     = {}
}
