provider "aws" {
  region = "eu-west-1"
}

# collect the most recent AMI for the region that are required for the VPCs and EC2 instances

data "aws_ami" "amazon_linux" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-2.0.*-x86_64-gp2"]
  }
  owners = ["amazon"]
}

resource "aws_ec2_transit_gateway" "tgw" {
  description = "regional_tgw"
}

resource "aws_vpc" "vpcs" {
  for_each            = var.vpcs
  ipv4_ipam_pool_id   = var.pool_id
  ipv4_netmask_length = 16
  depends_on = [
    var.cidr_block
  ]
  tags = {
    Name = "tf-${each.key}"
  }
}

resource "aws_subnet" "prvSubnets" {
  for_each                = aws_vpc.vpcs
  vpc_id                  = each.value.id
  cidr_block              = cidrsubnet(each.value.cidr_block, 4, 0) // fixme - not shifting any bits since we are creating a single subnet for each VPC. To be updated later
  map_public_ip_on_launch = false                                   // private subnets only
  tags = {
    Name = "tf-${cidrsubnet(each.value.cidr_block, 4, 0)}"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgwAttachments" {
  for_each           = { for k, v in aws_subnet.prvSubnets : k => v } // potential fixme - retest this with multiple subnets in a VPC
  subnet_ids = [each.value.id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = each.value.vpc_id
}

# Must attach the VPC (in question) to the TGW prior to add a route to the table. 

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
  depends_on = [ aws_ec2_transit_gateway_vpc_attachment.tgwAttachments[each] ]
}
*/
output "test_output" {
  #value = { for k, v in aws_vpc.vpcs : k => v }
  value = { for k, v in aws_subnet.prvSubnets : k => v }
}

/*
  ~ test_output = {
      + vpc-1 = {
          + arn                                            = "arn:aws:ec2:eu-west-1:747433832000:subnet/subnet-016379940f06c6c17"
          + assign_ipv6_address_on_creation                = false
          + availability_zone                              = "eu-west-1c"
          + availability_zone_id                           = "euw1-az3"
          + cidr_block                                     = "10.50.0.0/20"
          + customer_owned_ipv4_pool                       = ""
          + enable_dns64                                   = false
          + enable_lni_at_device_index                     = 0
          + enable_resource_name_dns_a_record_on_launch    = false
          + enable_resource_name_dns_aaaa_record_on_launch = false
          + id                                             = "subnet-016379940f06c6c17"
          + ipv6_cidr_block                                = ""
          + ipv6_cidr_block_association_id                 = ""
          + ipv6_native                                    = false
          + map_customer_owned_ip_on_launch                = false
          + map_public_ip_on_launch                        = false
          + outpost_arn                                    = ""
          + owner_id                                       = "747433832000"
          + private_dns_hostname_type_on_launch            = "ip-name"
          + tags                                           = {
              + Name = "tf-10.50.0.0/20"
            }
          + tags_all                                       = {
              + Name = "tf-10.50.0.0/20"
            }
          + timeouts                                       = null
          + vpc_id                                         = "vpc-0cc80728de0695a21"
        }
      + vpc-2 = {
          + arn                                            = "arn:aws:ec2:eu-west-1:747433832000:subnet/subnet-02eece771f0a99e03"
          + assign_ipv6_address_on_creation                = false
          + availability_zone                              = "eu-west-1a"
          + availability_zone_id                           = "euw1-az1"
          + cidr_block                                     = "10.51.0.0/20"
          + customer_owned_ipv4_pool                       = ""
          + enable_dns64                                   = false
          + enable_lni_at_device_index                     = 0
          + enable_resource_name_dns_a_record_on_launch    = false
          + enable_resource_name_dns_aaaa_record_on_launch = false
          + id                                             = "subnet-02eece771f0a99e03"
          + ipv6_cidr_block                                = ""
          + ipv6_cidr_block_association_id                 = ""
          + ipv6_native                                    = false
          + map_customer_owned_ip_on_launch                = false
          + map_public_ip_on_launch                        = false
          + outpost_arn                                    = ""
          + owner_id                                       = "747433832000"
          + private_dns_hostname_type_on_launch            = "ip-name"
          + tags                                           = {
              + Name = "tf-10.51.0.0/20"
            }
          + tags_all                                       = {
              + Name = "tf-10.51.0.0/20"
            }
          + timeouts                                       = null
          + vpc_id                                         = "vpc-0651be7d75ba14747"
        }
    }

──────────────────────────────────────────────────────────────────────────────────────────
*/