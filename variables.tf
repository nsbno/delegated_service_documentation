variable "name_prefix" {
  description = "A prefix used for naming resources."
  type        = string
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

variable "timeout" {
  description = "sqs timeout"
  default     = 180
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = map(string)
  default     = {}
}
