variable "prefix" {
  default = "hci"
}

variable "project" {
  default = "hybrid-cloud-iac"
}

variable "contact" {
  default = "oz.enterprises@icloud.com"
}

variable "ipam_regions" {
  type    = list(any)
  default = ["us-west-1", "eu-west-2"]
}
