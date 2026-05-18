variable "adfname" {
  type        = string
  description = "name of the data factory"
}
variable "rgname" {
  type        = string
  description = "resource group name"
}

variable "location" {
  type        = string
  description = "namw of the location"
}

variable "groupname" {
  type        = string
  description = "name of the azure ad group with storage blob data contributor role"
}
