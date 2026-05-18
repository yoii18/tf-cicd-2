variable "rgname" {
  type        = string
  description = "resource group name"
}

variable "strgacctname" {
  type        = string
  description = "name of the storage account"
}

variable "location" {
  type        = string
  description = "name of the location"
}

variable "groupname" {
  type        = string
  description = "name of the azure ad group with storage blob data contributor role"
}

variable "adfname" {
  type        = string
  description = "name of the data factory"
}
