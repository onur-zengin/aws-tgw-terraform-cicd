provider "aws" {
  alias  = "cal"
  region = "us-west-1"

  # Requester's credentials.
}

provider "aws" {
  alias  = "lon"
  region = "eu-west-2"

  # Accepter's credentials.
}

resource "aws_vpc_peering_connection" "foo2" {
  provider    = aws.cal
  vpc_id      = module.California.vpc-1_id
  peer_vpc_id = module.London.vpc-1_id
  peer_region = "eu-west-2"
  auto_accept = false // If both VPCs are not in the same AWS account and region do not enable the auto_accept attribute. The accepter can manage its side of the connection using the aws_vpc_peering_connection_accepter resource. 

  tags = {
    Side = "Requester"
  }
}

resource "aws_vpc_peering_connection_accepter" "bar2" {
  provider                  = aws.lon
  vpc_peering_connection_id = aws_vpc_peering_connection.foo2.id
  auto_accept               = true

  tags = {
    Side = "Accepter"
  }
}