terraform {

  backend "s3" {
    bucket         = "tfstate-hci"
    key            = "regional/eu-central-1/main/hci.tfstate"
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

  region = var.region

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

# Collect the current region, available AZs and the most recent AMI;

data "aws_region" "current" {

}

data "aws_availability_zones" "available" {

  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

data "aws_ami" "amazon_linux" {

  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-2.0.*-x86_64-gp2"]
  }
  owners = ["amazon"]
}




locals {

  # Extract the root_cidr to define private blocks for the SG allow lists
  # and the regional pool_id to be allocated to the VPC resource block;

  prv_cidr = data.terraform_remote_state.ipam.outputs.rootCidr
  pool_id  = data.terraform_remote_state.ipam.outputs.regionalPools[data.aws_region.current.name].ipam_pool_id

  # TGW requires an attachment subnet per-AZ per-VPC.
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

  # We need another collection where the subnets and route_tables
  # are associated with each other through the VPCs they belong to.
  # Extracting main/default route_table from the VPCs in a single loop 
  # could also be possible, but avoided working with default RTs to
  # maintain adaptability to different VPC environments. 

  route_tables = flatten([
    for subnet_key, subnet in aws_subnet.prvSubnets : [
      for rt_key, rt in aws_route_table.prvRouteTables : {
        subnet_id = subnet.id
        rt_id     = rt.id
      }
      if subnet.vpc_id == rt.vpc_id
    ]
  ])

  security_groups = flatten([
    for subnet_key, subnet in aws_subnet.prvSubnets : [
      for sg_key, sg in aws_security_group.prvSGs : {
        subnet_id = subnet.id
        sg_id     = sg.id
      }
      if subnet.vpc_id == sg.vpc_id
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
    Name = "tf-vpc-${count.index}"
  }

}


# When you attach a VPC to a TGW, you must specify one subnet from
# each Availability Zone to be used by the TGW to route traffic.

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


resource "aws_ec2_transit_gateway" "tgw" {

  description = "regional_tgw"

}


# Even though a TGW should be associated with one subnet per-AZ,
# the tgwAttachments resource block is called for an entire VPC.
# Therefore, the initial for_each loop should iterate through the 
# existing VPCs, while the list of subnet_ids is built with another 
# for expression afterwards; 

resource "aws_ec2_transit_gateway_vpc_attachment" "tgwAttachments" {

  for_each           = { for key, vpc in aws_vpc.vpcs : key => vpc }
  subnet_ids         = [for subnet in aws_subnet.prvSubnets : subnet.id if subnet.vpc_id == each.value.id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = each.value.id

}


resource "aws_route_table" "prvRouteTables" {

  # As before, aws_vpc.vpcs is a tuple so we must project it into a map;
  for_each = { for key, vpc in aws_vpc.vpcs : key => vpc }
  vpc_id   = each.value.id

  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }

  tags = {
    Name = "tf-default-route-to-tgw"
  }

  # A VPC must be attached to a TGW prior to adding routes referencing 
  # the gateway in its route table;
  depends_on = [aws_ec2_transit_gateway_vpc_attachment.tgwAttachments]

}


resource "aws_route_table_association" "associations" {

  for_each       = { for key, entry in local.route_tables : key => entry }
  subnet_id      = each.value.subnet_id
  route_table_id = each.value.rt_id

}


# Create an EC2 host per-subnet for connectivity testing;

resource "aws_instance" "prvHosts" {

  for_each               = { for key, subnet in aws_subnet.prvSubnets : key => subnet }
  subnet_id              = each.value.id
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [for entry in local.security_groups : entry.sg_id if entry.subnet_id == each.value.id]
  tags = {
    Name = "tf_host-${each.key}"
  }
}


resource "aws_security_group" "prvSGs" {

  for_each = { for key, vpc in aws_vpc.vpcs : key => vpc }
  vpc_id   = each.value.id

  dynamic "ingress" {
    iterator = port
    for_each = var.prvSgPorts
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = [local.prv_cidr]
    }
  }

  # accept ICMP type 8 (echo request) from private ranges
  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "1"
    cidr_blocks = [local.prv_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.prv_cidr]
  }
}



resource "aws_ec2_transit_gateway_peering_attachment_accepter" "fra-dub" {
  transit_gateway_attachment_id = local.tgw_peering_dub-fra

  tags = {
    Name = "TGW Peering Acceptor"
  }
}


data "terraform_remote_state" "dub" {

  backend = "s3"

  config = {
    bucket = "tfstate-hci"
    key    = "regional/eu-west-1/main/hci.tfstate"
    region = "us-east-1"
  }
}

locals {
    tgw_peering_dub-fra = data.terraform_remote_state.dub.outputs.tgw_peering_dub-fra
}