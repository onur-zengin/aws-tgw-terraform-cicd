variable "resource_prefix" {
  type    = string
  default = "iac"
}

variable "repository_name" {
  type = string
}

variable "default_branch" {
  type    = string
  default = "main"
}

variable "environment_prefixes" {
  type    = list(string)
  default = ["dev"]
}
