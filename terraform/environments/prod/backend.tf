terraform {
  backend "s3" {
    bucket         = "cse-pa-final-tfstate-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "cse-pa-final-tfstate-lock-prod"
    kms_key_id     = "alias/cse-pa-final-prod-s3"
  }
}
