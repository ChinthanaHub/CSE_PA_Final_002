terraform {
  backend "s3" {
    bucket       = "cse-pa-final-tfstate-dev"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
    kms_key_id   = "alias/cse-pa-final-dev-s3"
  }
}





















