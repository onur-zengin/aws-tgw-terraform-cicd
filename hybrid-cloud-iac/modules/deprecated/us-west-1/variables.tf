variable "pool_id" {
  description = "IPAM Pool ID"
  type        = string
}

variable "cidr_block" {
  description = "IPAM CIDR Block Object"
}

variable "peering_to_lon" {
  description = "VPC Peering Connection to London"
}