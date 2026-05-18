resource "azurerm_storage_account" "strgacct" {
  location                 = var.location
  name                     = var.strgacctname
  resource_group_name      = var.rgname
  min_tls_version          = "TLS1_2"
  account_replication_type = "LRS"
  account_tier             = "Standard"
  is_hns_enabled           = true
}
