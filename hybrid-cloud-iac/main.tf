terraform {
  backend "s3" {
    bucket         = "tfstate-hybrid-nw"
    key            = "hybrid-nw.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "tfstate-lock_hybrid-nw"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    awscc = {
      source = "hashicorp/awscc"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "awscc" {
  region = "us-east-1"
}

locals {
  prefix = "${var.prefix}-${terraform.workspace}"
  common_tags = {
    Project     = var.project
    Environment = terraform.workspace
    Owner       = var.contact
    ManagedBy   = "Terraform"
  }
}

resource "awscc_ec2_ipam" "main" {
  operating_regions = [
    {
      region_name = "eu-west-2"
    },
    {
      region_name = "us-west-1"
    }
  ]
  tags = [{
    key   = "Name"
    value = "global-ipam"
  }]
}

resource "awscc_ec2_ipam_pool" "root" {
  address_family = "ipv4"
  ipam_scope_id  = awscc_ec2_ipam.main.private_default_scope_id
  auto_import    = false

  provisioned_cidrs = [
    {
      cidr = "10.0.0.0/8"
    }
  ]
/*
  tags = merge(
    local.common_tags,
    tomap({ "Name" = "${local.prefix}-bastion" })
  )
*/
  tags = [{
    key   = "Name"
    value = "top-level-pool"
  }]
}

resource "awscc_ec2_ipam_pool" "eu-west-2" {
  address_family      = "ipv4"
  auto_import         = false
  ipam_scope_id       = awscc_ec2_ipam.main.private_default_scope_id
  locale              = "eu-west-2"
  source_ipam_pool_id = awscc_ec2_ipam_pool.root.ipam_pool_id

  provisioned_cidrs = [
    {
      cidr = "10.0.0.0/16"
    }
  ]

  tags = [{
    key   = "Name"
    value = "regional-pool-eu-west-2"
  }]
}

resource "awscc_ec2_ipam_pool" "us-west-1" {
  address_family      = "ipv4"
  auto_import         = false
  ipam_scope_id       = awscc_ec2_ipam.main.private_default_scope_id
  locale              = "us-west-1"
  source_ipam_pool_id = awscc_ec2_ipam_pool.root.ipam_pool_id

  provisioned_cidrs = [
    {
      cidr = "10.1.0.0/16"
    }
  ]

  tags = [{
    key   = "Name"
    value = "regional-pool-us-west-1"
  }]
}


module "London" {
  source = "./eu-west-2"
}
module "California" {
  source = "./us-west-1"
  pool = awscc_ec2_ipam_pool.us-west-1.id
}