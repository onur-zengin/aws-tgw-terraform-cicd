variable "project" {
  default = "hybrid-cloud-iac"
}

variable "prefix" {
  default = "hci"
}

variable "contact" {
  default = "oz.enterprises@icloud.com"
}

variable "cicd_region" {
  type    = string
  default = "us-east-1"
}

variable "target_region" {
  type    = string
  default = "eu-west-1"
}

# fixme - make the following list dynamic. Read the existing from backend and append the new target region in each iteration
variable "target_regions" {
  type = list(string)
  #default = ["us-west-1", "eu-west-2", "eu-west-1", "eu-central-1"]
  default = ["eu-west-1", "eu-west-2"]
}


variable "nvironment_prefixes" {
  type    = list(string)
  default = ["dev", "prod"]
}
