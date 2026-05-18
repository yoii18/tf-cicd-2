##### main resource, linked services, assign adf to group using staging app (azuread provider) #####
resource "azurerm_data_factory" "adf" {
  name                = var.adfname
  resource_group_name = var.rgname
  location            = var.location

  identity {
    type = "SystemAssigned"
  }
}

data "azuread_group" "storage_blob_contributors" {
  display_name     = var.groupname
  security_enabled = true
}

# data "azurerm_data_factory" "adf" {
#   name                = var.adfname
#   resource_group_name = var.rgname
# }

data "azuread_service_principal" "adf_sp" {
  object_id  = azurerm_data_factory.adf.identity[0].principal_id
  depends_on = [azurerm_data_factory.adf]
}

resource "azuread_group_member" "storage_blob_group_member_addition" {
  member_object_id = data.azuread_service_principal.adf_sp.object_id
  group_object_id  = data.azuread_group.storage_blob_contributors.object_id
}
