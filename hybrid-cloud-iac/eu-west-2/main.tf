# set the provider region specific to the module
# w/out this definition here, the child module would inherit the working region (us-east-1) from root
provider "aws" {
  region = "eu-west-2"
}

# collect the available AZs and the most recent AMI for the region that are required for the VPCs and EC2 instances, respectively
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

#azs  = data.aws_availability_zones.available.names

data "aws_ami" "amazon_linux" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-2.0.*-x86_64-gp2"]
  }
  owners = ["amazon"]
}

/*
resource "aws_ec2_transit_gateway" "lon" {
  description = "example"
}
*/

# Note that when the VPC CIDRs are IPAM managed, VPC deletion may take longer than expected (>15mins)
# https://github.com/hashicorp/terraform-provider-aws/issues/31211

resource "aws_vpc" "eu-west-2-vpc-1" {
  ipv4_ipam_pool_id   = var.pool_id
  ipv4_netmask_length = 16
  depends_on = [
    var.cidr_block
  ]
  tags = {
    Name = "tform-1"
  }
}


resource "aws_subnet" "prv-1a" {
  vpc_id     = aws_vpc.eu-west-2-vpc-1.id
  availability_zone = "eu-west-2a" // randomly-assigned if not specified
  cidr_block = cidrsubnet(aws_vpc.eu-west-2-vpc-1.cidr_block, 4, 2)
  map_public_ip_on_launch = false  
  tags = {
    Name = "tform_prv-vpc1-a"
  }
}

resource "aws_subnet" "pub-1a" {
  vpc_id     = aws_vpc.eu-west-2-vpc-1.id
  availability_zone = "eu-west-2a"
  cidr_block = cidrsubnet(aws_vpc.eu-west-2-vpc-1.cidr_block, 4, 4)
  map_public_ip_on_launch = true // to determine whether a nw interface created in this subnet is auto-assigned a public IP  
  tags = {
    Name = "tform_pub-vpc1-a" 
  }
}


resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.pub-1a.id
  tags = {
    Name = "tf_bastion" 
  }
}

resource "aws_instance" "host-1" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.prv-1a.id
  tags = {
    Name = "tf_host-1" 
  }
}

