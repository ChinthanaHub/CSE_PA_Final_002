terraform {
  backend "s3" {
    bucket         = "cse-pa-final-tfstate-dev"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "cse-pa-final-tfstate-lock-dev"
    kms_key_id     = "alias/cse-pa-final-dev-s3"
  }
}

