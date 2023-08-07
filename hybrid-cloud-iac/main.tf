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
      source  = "hashicorp/awscc"
      version = "~> 0.57"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "awscc" {
  region = "us-east-1"
}

data "aws_region" "current" {}

locals {
  # ensure current provider region is an operating_regions entry
  all_ipam_regions = distinct(concat([data.aws_region.current.name], var.ipam_regions))
  # additional locals for tagging
  prefix = "${var.prefix}-${terraform.workspace}"
  common_tags = {
    Project     = var.project
    Environment = terraform.workspace
    Owner       = var.contact
    ManagedBy   = "Terraform"
  }
}

resource "aws_vpc_ipam" "main" {
  dynamic "operating_regions" {
    for_each = local.all_ipam_regions
    content {
      region_name = operating_regions.value
    }
  }
}

resource "aws_vpc_ipam_pool" "root" {
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.main.private_default_scope_id
  auto_import    = false
}

resource "aws_vpc_ipam_pool_cidr" "root_block" {
  ipam_pool_id = aws_vpc_ipam_pool.root.id
  cidr         = "10.0.0.0/8"
}

resource "aws_vpc_ipam_pool" "us-west-1" {
  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam.main.private_default_scope_id
  locale              = "us-west-1"
  source_ipam_pool_id = aws_vpc_ipam_pool.root.id
}

resource "aws_vpc_ipam_pool" "eu-west-2" {
  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam.main.private_default_scope_id
  locale              = "eu-west-2"
  source_ipam_pool_id = aws_vpc_ipam_pool.root.id
}

resource "aws_vpc_ipam_pool_cidr" "us-west-1_block" {
  ipam_pool_id = aws_vpc_ipam_pool.us-west-1.id
  cidr         = "10.0.0.0/15"
}

resource "aws_vpc_ipam_pool_cidr" "eu-west-2_block" {
  ipam_pool_id = aws_vpc_ipam_pool.eu-west-2.id
  cidr         = "10.2.0.0/15"
}

module "California" {
  source = "./us-west-1"
  pool   = aws_vpc_ipam_pool.us-west-1.id
  cidr   = aws_vpc_ipam_pool_cidr.us-west-1_block.cidr
}

module "London" {
  source = "./eu-west-2"
  pool   = aws_vpc_ipam_pool.eu-west-2.id
  cidr   = aws_vpc_ipam_pool_cidr.eu-west-2_block.cidr
}