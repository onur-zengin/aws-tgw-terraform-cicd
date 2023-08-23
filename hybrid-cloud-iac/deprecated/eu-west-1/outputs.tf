output "tgw_id" {
    value = aws_ec2_transit_gateway.tgw.id
}

output "tgw_peering_dub-fra" {
    value = aws_ec2_transit_gateway_peering_attachment.dub-fra.id
}