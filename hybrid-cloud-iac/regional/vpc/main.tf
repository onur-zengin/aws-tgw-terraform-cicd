# Referencing the global remote backend to extract IPAM regionalPools;

data "terraform_remote_state" "backend" {

  backend = "s3"

  config = {
    bucket = "tfstate-hci"
    key    = "global/main/hci.tfstate"
    region = var.cicd_region
  }
}

# Collect the current region & available AZs;

data "aws_region" "current" {}

data "aws_availability_zones" "available" {

  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}


locals {

  region = data.aws_region.current

  # Extract the regional pool_id to be used by the VPC resource block;

  pool_id  = data.terraform_remote_state.backend.outputs.ipam[local.region.name].ipam_pool_id

  # A TGW requires an attachment subnet per-AZ per-VPC.
  # So, in order to declare all of the subnets with a single resource block; 
  # we will first flatten the structure to produce a collection, where we
  # combine the created VPCs and available AZs in the region.

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


# In order to deprovision CIDRs all allocations must be released. 
# However, allocations created by a VPC can take up to 30 minutes 
# to be released, prolonging a VPC deletion operation. Also see;
# https://github.com/hashicorp/terraform-provider-aws/issues/31211

resource "aws_vpc" "vpcs" {

  count               = var.vpc_count
  ipv4_ipam_pool_id   = local.pool_id
  ipv4_netmask_length = 16
  tags = {
    Name = "TF_${local.region.name}-vpc-${count.index}"
  }

}


# When you attach a VPC to a TGW, you must specify one subnet from
# each Availability Zone to be used by the gateway to route traffic

resource "aws_subnet" "prvSubnets" {

  # local.subnets is a tuple of objects, so we must now project it into a map;
  for_each                = { for key, subnet in local.subnets : key => subnet }
  vpc_id                  = each.value.vpc_id
  availability_zone       = each.value.zone_name
  cidr_block              = cidrsubnet(each.value.vpc_cidr, each.value.newbits, each.value.zone_key)
  map_public_ip_on_launch = false // private subnets only

  tags = {
    Name = "${each.value.vpc_name}-tgw-${each.value.zone_name}"
  }

}

