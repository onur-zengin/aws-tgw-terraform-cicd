provider "aws" {
  region = "us-west-1"
}

locals {
  prvTcpPorts = [22, 80, 443, 3306]
  prvUdpPorts = []
  prvCidrBlocks = ["10.0.0.0/8"]
}

# collect the available AZs and the most recent AMI for the region that are required for the VPCs and EC2 instances, respectively

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

output "az" {
  value = data.aws_availability_zones.available.names
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-2.0.*-x86_64-gp2"]
  }
  owners = ["amazon"]
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_vpc" "us-west-1-vpc-1" {
  ipv4_ipam_pool_id   = var.pool_id
  ipv4_netmask_length = 16
  depends_on = [
    var.cidr_block
  ]
  tags = {
    Name = "tform_vpc-1"
  }
}

resource "aws_vpc" "us-west-1-vpc-2" {
  ipv4_ipam_pool_id   = var.pool_id
  ipv4_netmask_length = 20
  depends_on = [
    var.cidr_block
  ]
  tags = {
    Name = "tform_vpc-2"
  }
}


resource "aws_subnet" "prv-1c" {
  vpc_id                  = aws_vpc.us-west-1-vpc-1.id
  availability_zone       = "us-west-1c"
  cidr_block              = cidrsubnet(aws_vpc.us-west-1-vpc-1.cidr_block, 4, 2)
  map_public_ip_on_launch = false // to determine whether a nw interface created in this subnet is auto-assigned a public IP
  tags = {
    Name = "tform_prv-vpc1-c"
  }
}

resource "aws_subnet" "prv-2b" {
  vpc_id                  = aws_vpc.us-west-1-vpc-2.id
  availability_zone       = "us-west-1b"
  cidr_block              = cidrsubnet(aws_vpc.us-west-1-vpc-2.cidr_block, 4, 2)
  map_public_ip_on_launch = false // to determine whether a nw interface created in this subnet is auto-assigned a public IP
  tags = {
    Name = "tform_prv-vpc2-b" // Typically for LBs or other front-facing infrastructure
  }
}


resource "aws_route_table" "privateRouteTable" {
  vpc_id = aws_vpc.us-west-1-vpc-1.id 
  route {
    cidr_block = "0.0.0.0/0"
    vpc_peering_connection_id = var.peering_to_lon.id
  }
  tags = {
    Name = "tf-prv-vpc-1"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.prv-1c.id
  route_table_id = aws_route_table.privateRouteTable.id
}


resource "aws_instance" "host-1" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.prv-1c.id
  vpc_security_group_ids = [ aws_security_group.private-sg-vpc-1.id ]
  tags = {
    Name = "tf_host-1"
  }
}

resource "aws_instance" "host-2" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.prv-2b.id
  vpc_security_group_ids = [ aws_security_group.private-sg-vpc-2.id ]

  tags = {
    Name = "tf_host-2"
  }
}


resource "aws_security_group" "private-sg-vpc-1" { 
    name = "generic-internal-vpc-1"  // Must be unique within a VPC
    vpc_id = aws_vpc.us-west-1-vpc-1.id 

    dynamic "ingress" {
        iterator = port
        for_each = local.prvTcpPorts
        content {
            from_port = port.value
            to_port = port.value
            protocol = "tcp"
            cidr_blocks = local.prvCidrBlocks
        }
    }

    dynamic "ingress" {
        iterator = port
        for_each = local.prvUdpPorts
        content {
            from_port = port.value
            to_port = port.value
            protocol = "udp"
            cidr_blocks = local.prvCidrBlocks
        }
    }

  # accept ICMP type 8 (echo request) from private ranges
    ingress {
        from_port = 8
        to_port = 0
        protocol = "1"
        cidr_blocks = local.prvCidrBlocks
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = local.prvCidrBlocks
    }
}

resource "aws_security_group" "private-sg-vpc-2" { 
    name = "generic-internal-vpc-2"  // Must be unique within a VPC
    vpc_id = aws_vpc.us-west-1-vpc-2.id 

    dynamic "ingress" {
        iterator = port
        for_each = local.prvTcpPorts
        content {
            from_port = port.value
            to_port = port.value
            protocol = "tcp"
            cidr_blocks = local.prvCidrBlocks
        }
    }

    dynamic "ingress" {
        iterator = port
        for_each = local.prvUdpPorts
        content {
            from_port = port.value
            to_port = port.value
            protocol = "udp"
            cidr_blocks = local.prvCidrBlocks
        }
    }

  # accept ICMP type 8 (echo request) from private ranges
    ingress {
        from_port = 8
        to_port = 0
        protocol = "1"
        cidr_blocks = local.prvCidrBlocks
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = local.prvCidrBlocks
    }
}