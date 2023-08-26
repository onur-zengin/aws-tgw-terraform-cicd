# [do-not-remove] required by the VPC module to extract regional IPAM pools
output "ipam" {
    value = module.ipam.regionalPools
}

/*
output "region" {
  value = local.region.name
}

output "location" {
  value = local.region.description
}
*/
/*
output "working_directory" {
    value = [
        module.vpc["0"].region,
        module.vpc["0"].local_subnets
    ]
}
*/