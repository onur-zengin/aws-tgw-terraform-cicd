provider "aws" {
  region = "us-west-1"
}

resource "aws_vpc" "us-west-1-vpc-1" {
  ipv4_ipam_pool_id   = var.pool
  ipv4_netmask_length = 16
  depends_on = [
    var.cidr
  ]
}
