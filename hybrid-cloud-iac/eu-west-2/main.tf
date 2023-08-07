# w/out a provider region definition here, the child module would inherit the working region (us-east-1) from root
provider "aws" {
  region = "eu-west-2"
}

# Note that when the VPC CIDRs are IPAM managed, VPC deletion may take longer than expected (>15mins)
# https://github.com/hashicorp/terraform-provider-aws/issues/31211

resource "aws_vpc" "eu-west-2-vpc-1" {
  ipv4_ipam_pool_id   = var.pool_id
  ipv4_netmask_length = 16
  depends_on = [
    var.cidr_block
  ]
}
