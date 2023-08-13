output "regionalPools" {
  value = { for k, v in aws_vpc_ipam_pool_cidr.regionalPools : k => v}
}