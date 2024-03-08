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