variable "prefix" {
  default = "hci"
}

variable "project" {
  default = "hybrid-cloud-iac"
}

variable "contact" {
  default = "oz.enterprises@icloud.com"
}

variable "root_cidr" {
  type    = string
  default = "10.0.0.0/8"
}

variable "operating_regions" {
  type    = list(any)
  default = ["us-west-1", "eu-west-2", "eu-west-1", "eu-central-1"]
}

variable "regional_pool_size" {
  type    = number
  default = 12
}