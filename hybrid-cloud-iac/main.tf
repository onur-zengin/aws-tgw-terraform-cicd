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


module "ipam" {

  source = "./global/ipam"
  cicd_region = var.cicd_region
  target_regions = var.target_regions

}


module "vpc" {

  source = "./regional/vpc"
  cicd_region = var.cicd_region
  providers = {
    aws = aws.target
  }

}