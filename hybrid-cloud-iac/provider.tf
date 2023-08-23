terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.cicd_region
}


provider "aws" {
  alias  = "target"
  region = var.target_region
}

/*
provider "aws" {
  alias  = "lon"
  region = "eu-west-2"
}
*/