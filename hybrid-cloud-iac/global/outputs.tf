# Output the root_cidr variable to enable access from 
# regional modules to create private SG rules

output "rootCidr" {
  value = var.root_cidr
}

output "regionalPools" {
  value = { for k, v in aws_vpc_ipam_pool_cidr.regionalPools : k => v}
}
