terraform {
  backend "s3" {
    bucket         = "tfstate-hci"
    key            = "regional/eu-west-1/main/hci.tfstate"
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
  region = "eu-west-1"
}

# Referencing the global remote backend to extract IPAM regionalPools;

data "terraform_remote_state" "ipam" {
  backend = "s3"

  config = {
    bucket = "tfstate-hci"
    key    = "global/main/hci.tfstate"
    region = "us-east-1"
  }
}

# Collect the current region and available AZs;

data "aws_region" "current" {
}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

locals {

  # Extract the regional pool_id for the VPC resource block;

  pool_id = data.terraform_remote_state.ipam.outputs.regionalPools[data.aws_region.current.name].ipam_pool_id

  # TGW requires an attachment subnet per-AZ per-VPC.
  # So, in order to declare all of the subnets with a single resource block; 
  # we will first flatten the structure to produce a collection, where
  # we combine the created VPCs and available AZs in the region.

  subnets = flatten([
    for vpc_key, vpc in aws_vpc.vpcs : [
      for zone_key, zone in data.aws_availability_zones.available.names : {
        vpc_id    = vpc.id
        vpc_name  = vpc.tags.Name
        vpc_cidr  = vpc.cidr_block
        newbits   = var.netmask - vpc.ipv4_netmask_length
        zone_key  = zone_key
        zone_name = zone
      }
    ]
  ])

}

# In order to deprovision CIDRs all Allocations must be released. 
# However, allocations created by a VPC can take up to 30 minutes 
# to be released, prolonging a VPC deletion operation. Also see;
# https://github.com/hashicorp/terraform-provider-aws/issues/31211

resource "aws_vpc" "vpcs" {
  count               = var.vpc_count
  ipv4_ipam_pool_id   = local.pool_id
  ipv4_netmask_length = 16
  tags = {
    Name = "tf-vpc-${count.index}"
  }
}

# When you attach a VPC to a transit gateway, you must specify one subnet from
# each Availability Zone to be used by the transit gateway to route traffic.
# local.subnets is a tuple of objects, so we must now project it into a map;

resource "aws_subnet" "prvSubnets" {
  for_each                = { for k, v in local.subnets : k => v }
  vpc_id                  = each.value.vpc_id
  availability_zone       = each.value.zone_name
  cidr_block              = cidrsubnet(each.value.vpc_cidr, each.value.newbits, each.value.zone_key)
  map_public_ip_on_launch = false // private subnets only
  tags = {
    Name = "${each.value.vpc_name}-tgw-${each.value.zone_name}"
  }
}


resource "aws_ec2_transit_gateway" "tgw" {
  description = "regional_tgw"
}

# Even though a TGW should be associated with one subnet per-AZ,
# the tgwAttachments resource block is called for an entire VPC.
# Therefore, the initial for_each loop should iterate through the VPCs,
# while the list of subnet_ids is built with another for expression; 

resource "aws_ec2_transit_gateway_vpc_attachment" "tgwAttachments" {
  for_each           = { for k, vpc in aws_vpc.vpcs : k => vpc } 
  subnet_ids         = [ for subnet in aws_subnet.prvSubnets : subnet.id if subnet.vpc_id == each.value.id ]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = each.value.id
}

/*

resource "aws_route_table" "prvRouteTables" {
  for_each = aws_vpc.vpcs
  vpc_id   = each.value.id
  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }
  tags = {
    Name = "tf-${each.key}"
  }

  # Must attach the VPC in question to the TGW prior to adding a route to the table
  depends_on = [ aws_ec2_transit_gateway_vpc_attachment.tgwAttachments ]
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.prv-1c.id
  route_table_id = aws_route_table.privateRouteTable.id
}

resource "aws_vpc_endpoint" "eps" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-west-2.ec2"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.sg1.id,
  ]

  private_dns_enabled = true
}
*/




/*

{ for k, v in aws_subnet.prvSubnets : k => v.id if v.vpc_id == "vpc-00e1a3874b6cc70e0"}
{
  "0" = "subnet-0ae8a6d794f83a0db"
  "1" = "subnet-00c3a13aaff697a94"
  "2" = "subnet-0076e1f07bc029ea5"
}

 { for k, v in local.subnets : k => v if v.vpc_id == "vpc-00e1a3874b6cc70e0"}
{
  "0" = {
    "newbits" = 12
    "vpc_cidr" = "10.49.0.0/16"
    "vpc_id" = "vpc-00e1a3874b6cc70e0"
    "vpc_name" = "tf-vpc-0"
    "zone_key" = 0
    "zone_name" = "eu-west-1a"
  }
  "1" = {
    "newbits" = 12
    "vpc_cidr" = "10.49.0.0/16"
    "vpc_id" = "vpc-00e1a3874b6cc70e0"
    "vpc_name" = "tf-vpc-0"
    "zone_key" = 1
    "zone_name" = "eu-west-1b"
  }
  "2" = {
    "newbits" = 12
    "vpc_cidr" = "10.49.0.0/16"
    "vpc_id" = "vpc-00e1a3874b6cc70e0"
    "vpc_name" = "tf-vpc-0"
    "zone_key" = 2
    "zone_name" = "eu-west-1c"
  }
}
*/
