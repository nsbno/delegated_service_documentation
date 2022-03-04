# delegated_service_documentation



```terraform
resource "aws_s3_bucket_object" "delegated_service_documentation" {​​
  bucket = local.service_documentation_bucket​​
  applicationname = ${var.name_prefix}
  slack = "#team-kjøretøy"

  api_gateway_arn = "arn:aws:1234"
  # OR
  swagger_file = file("./test.openapi.yaml")

  about_file = file("./docs/about.adoc")
  owner = "budgetowner"@vy.no
  technicalowner = "tekniskowner"@vy.no
  servicesla = "99.8"
  growthmetric = "transaction count"
  aktivitetskode = "123533"

  content_type = "application/json"​
}​
```
