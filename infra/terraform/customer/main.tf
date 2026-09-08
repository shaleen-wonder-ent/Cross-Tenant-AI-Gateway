resource "azurerm_resource_group" "this" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.10.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.10.2.0/24"]
}

resource "azurerm_private_dns_zone" "apim" {
  name                = "privatelink.azure-api.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "apim" {
  name                  = "link-azure-api-net"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.apim.name
  virtual_network_id    = azurerm_virtual_network.this.id
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "apim" {
  name                = "${var.prefix}-apim-pe"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "apim"
    private_connection_resource_id = var.provider_apim_id
    subresource_names              = ["Gateway"]
    is_manual_connection           = true
    request_message                = "Cross-tenant private connection to the provider AI gateway"
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.apim.id]
  }
}

resource "azuread_service_principal" "provider_api" {
  client_id = var.provider_api_client_id
}

resource "azuread_application" "client" {
  display_name     = "${var.prefix}-client"
  sign_in_audience = "AzureADMyOrg"

  required_resource_access {
    resource_app_id = var.provider_api_client_id

    resource_access {
      id   = var.model_invoke_app_role_id
      type = "Role"
    }
  }
}

resource "azuread_service_principal" "client" {
  client_id = azuread_application.client.client_id
}

resource "azuread_app_role_assignment" "model_invoke" {
  app_role_id         = var.model_invoke_app_role_id
  principal_object_id = azuread_service_principal.client.object_id
  resource_object_id  = azuread_service_principal.provider_api.object_id
}

resource "azurerm_network_interface" "test" {
  count = var.create_test_vm ? 1 : 0

  name                = "${var.prefix}-test-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "test" {
  count = var.create_test_vm ? 1 : 0

  name                            = "${var.prefix}-test-vm"
  location                        = azurerm_resource_group.this.location
  resource_group_name             = azurerm_resource_group.this.name
  size                            = "Standard_B2ts_v2"
  admin_username                  = "azureuser"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.test[0].id]
  tags                            = var.tags

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
