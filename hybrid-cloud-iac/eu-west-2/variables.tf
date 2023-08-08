variable "pool_id" {
  description = "IPAM Pool ID"
  type        = string
}

variable "cidr_block" {
  description = "IPAM CIDR Block Object"
}

variable "connection_id" {
  description = "VPC connection ID"
  type = string
}