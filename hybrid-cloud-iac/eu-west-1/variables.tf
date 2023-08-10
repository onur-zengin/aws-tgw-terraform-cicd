variable "pool_id" {
  description = "IPAM Pool ID"
  type        = string
}

variable "cidr_block" {
  description = "IPAM CIDR Block Object"
}

variable "vpcs" {
  type = map(any)
  default = {
    "vpc-1" = {}
    "vpc-2" = {}
  }
}