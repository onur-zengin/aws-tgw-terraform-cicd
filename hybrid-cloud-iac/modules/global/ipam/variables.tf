variable "cicd_region" {
  type = string
}

variable "target_regions" {
  type    = list(string)
}

variable "root_cidr" {
  type    = string
  default = "10.0.0.0/8"
}

variable "regional_pool_size" {
  type    = number
  default = 12
}
