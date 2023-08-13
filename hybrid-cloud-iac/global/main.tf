terraform {
  backend "s3" {
    bucket         = "tfstate-hci"
    key            = "global/main/hci.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "tfstate-lock-hci"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_region" "current" {
}

locals {
  
  # have to ensure that current provider region is an operating_regions entry for IPAM
  all_ipam_regions = distinct(concat([data.aws_region.current.name], var.operating_regions))
  newbits          = var.regional_pool_size - split("/", var.root_cidr)[1]

  # additional locals for tagging
  prefix = "${var.prefix}-${terraform.workspace}"
  common_tags = {
    Project     = var.project
    Environment = terraform.workspace
    Owner       = var.contact
    ManagedBy   = "Terraform"

  # local region
  region = data.aws_region.current
  }
}

# Following first block is the boilerplate implementation of aws_vpc_ipam.main 
# from Terraform

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

resource "aws_vpc_ipam_pool_cidr" "root_cidr" {
  ipam_pool_id = aws_vpc_ipam_pool.root.id
  cidr         = var.root_cidr
}

resource "aws_vpc_ipam_pool" "regionalPools" {
  for_each            = toset(local.all_ipam_regions)
  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam.main.private_default_scope_id
  description         = each.value
  locale              = each.value
  source_ipam_pool_id = aws_vpc_ipam_pool.root.id
}

# Notice that k & v are swapped around in the following map generation statement
# That is because the keys (k) include region-names and we want to keep them intact 
# to maintain consinstency with the aws_vpc_ipam_pool.Regionalpools table above
# That consistency is important to be able to access both the pool_id & cidr together
# from under the aws_vpc_ipam_pool_cidr.regionalPools table inside the VPC module later

resource "aws_vpc_ipam_pool_cidr" "regionalPools" {
  for_each = { for k, v in toset(local.all_ipam_regions) : v => index(flatten(local.all_ipam_regions), k)}
  ipam_pool_id = aws_vpc_ipam_pool.regionalPools[each.key].id
  cidr         = cidrsubnet(var.root_cidr, local.newbits, each.value)
}
