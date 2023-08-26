# data "aws_region" "current" {}

locals {

  #region = data.aws_region.current -- fixme - replace var.cicd_region with this
  
  # Have to ensure that current working region is included in the 
  # operating_regions for IPAM;
  
  all_ipam_regions = distinct(concat([var.cicd_region], var.target_regions))
  newbits          = var.regional_pool_size - split("/", var.root_cidr)[1]

}

# The first resource block below is mostly the boilerplate implementation of
# aws_vpc_ipam from Terraform documentation. The cascade parameter was added
# later to mitigate the dependency errors encountered during deprovisioning.

resource "aws_vpc_ipam" "main" {

  cascade = true
  dynamic "operating_regions" {
    for_each = local.all_ipam_regions
    content {
      region_name = operating_regions.value
    }
  }

}

resource "aws_vpc_ipam_pool" "root" {

  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.main.private_default_scope_id
  auto_import    = false

}

resource "aws_vpc_ipam_pool_cidr" "root_cidr" {

  ipam_pool_id = aws_vpc_ipam_pool.root.id
  cidr         = var.root_cidr

}

resource "aws_vpc_ipam_pool" "regionalPools" {

  for_each            = toset(local.all_ipam_regions)
  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam.main.private_default_scope_id
  description         = each.value
  locale              = each.value
  source_ipam_pool_id = aws_vpc_ipam_pool.root.id

}

# Notice that k & v are swapped around in the following map generation statement
# That is because the keys (k) include region-names and we want to keep them intact 
# to maintain consinstency with the aws_vpc_ipam_pool.Regionalpools table above
# That consistency is important to be able to access both the pool_id & cidr together
# from under the aws_vpc_ipam_pool_cidr.regionalPools table inside the VPC module later

resource "aws_vpc_ipam_pool_cidr" "regionalPools" {

  for_each = { for k, v in toset(local.all_ipam_regions) : v => index(flatten(local.all_ipam_regions), k)}
  ipam_pool_id = aws_vpc_ipam_pool.regionalPools[each.key].id
  cidr         = cidrsubnet(var.root_cidr, local.newbits, each.value) # fixme - P3 - this results in regional pools being re-allocated should one of them in a lower index be removed.

}
