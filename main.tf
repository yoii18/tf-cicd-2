resource "azurerm_resource_group" "rg" {
  name     = var.rgname
  location = var.location
}

module "strgacct" {
  source       = "./modules/strgacct"
  rgname       = var.rgname
  location     = var.location
  strgacctname = var.strgacctname

  depends_on = [azurerm_resource_group.rg]
}
