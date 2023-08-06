resource "aws_vpc" "us-west-1" {
  #cidr_block = "10.0.0.0/24"
  ipv4_ipam_pool_id   = var.pool
  ipv4_netmask_length = 16

  tags = {
    Name = "us-west-1"
  }
}
