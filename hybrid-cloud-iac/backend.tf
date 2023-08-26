terraform {
  backend "s3" {
    bucket         = "tfstate-hci"
    key            = "global/main/hci.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-lock-hci"
    encrypt        = true
  }
}