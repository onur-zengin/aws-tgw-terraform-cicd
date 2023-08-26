locals {

  /* placeholder
  # additional locals for tagging
  prefix = "${var.prefix}-${terraform.workspace}"
  common_tags = {
    Project     = var.project
    Environment = terraform.workspace
    Owner       = var.contact
    ManagedBy   = "Terraform"
  */

}

module "cicd" {

  source          = "./modules/global/cicd"
  repository_name = var.project

}

module "ipam" {

  source         = "./modules/global/ipam"
  cicd_region    = var.cicd_region
  target_regions = var.target_regions

}
/*
module "vpc" {

  source      = "./modules/regional/vpc"
  cicd_region = var.cicd_region
  providers = {
    aws = aws.target
  }

}

EVERY NEW REGION TAG SHOULD AUTO-DISCOVER THE EXISTING ONES AND CONNECT ITSELF

*/

