
variable "vpc_count" {
  type    = number
  default = 1
}

# AWS recommended design best practice for TGW-attachment subnets is a /28 per-AZ
variable "netmask" {
  type    = number
  default = 28
}


variable "prvSgPorts" {
  type    = list(number)
  default = [22, 80, 443, 3306]
}

