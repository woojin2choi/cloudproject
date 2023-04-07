terraform {
  backend "s3" {
    bucket = "cicdworkshop-339404323309-sds-cicd"
    key    = "1-getting-started/backend-s3-terraform.tfstate"
    region = "ap-northeast-2"
    dynamodb_table = "cicdworkshop-table"
    encrypt = true
  }
}
