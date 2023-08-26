
resource "aws_ec2_transit_gateway" "tgw" {

  description = "regional_tgw"
  amazon_side_asn = var.regional_asn 
  #auto_accept_shared_attachments = enable // test enabling this - is there a security risk?
  #default_route_table_association = enable

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
