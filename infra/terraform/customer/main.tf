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

# Caller's public IP, used to lock down the demo VM's NSG when not overridden.
data "http" "myip" {
  count = var.create_test_vm && trimspace(var.allowed_client_ip) == "" ? 1 : 0
  url   = "https://api.ipify.org"
}

locals {
  allowed_client_ip = var.create_test_vm ? (
    trimspace(var.allowed_client_ip) != "" ? trimspace(var.allowed_client_ip) : trimspace(data.http.myip[0].response_body)
  ) : ""
}

resource "tls_private_key" "vm" {
  count     = var.create_test_vm ? 1 : 0
  algorithm = "ED25519"
}

resource "local_sensitive_file" "vm_key" {
  count           = var.create_test_vm ? 1 : 0
  filename        = "${path.module}/.ssh/${var.prefix}-vm.pem"
  content         = tls_private_key.vm[0].private_key_openssh
  file_permission = "0600"
}

resource "azurerm_public_ip" "test" {
  count = var.create_test_vm ? 1 : 0

  name                = "${var.prefix}-test-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_security_group" "test" {
  count = var.create_test_vm ? 1 : 0

  name                = "${var.prefix}-test-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${local.allowed_client_ip}/32"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-web"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.web_port)
    source_address_prefix      = "${local.allowed_client_ip}/32"
    destination_address_prefix = "*"
  }
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
    public_ip_address_id          = azurerm_public_ip.test[0].id
  }
}

resource "azurerm_network_interface_security_group_association" "test" {
  count = var.create_test_vm ? 1 : 0

  network_interface_id      = azurerm_network_interface.test[0].id
  network_security_group_id = azurerm_network_security_group.test[0].id
}

resource "azurerm_linux_virtual_machine" "test" {
  count = var.create_test_vm ? 1 : 0

  name                            = "${var.prefix}-test-vm"
  location                        = azurerm_resource_group.this.location
  resource_group_name             = azurerm_resource_group.this.name
  size                            = var.vm_size
  admin_username                  = "azureuser"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.test[0].id]
  tags                            = var.tags

  custom_data = base64encode(templatefile("${path.module}/cloudinit.yaml.tftpl", {
    app_py_b64   = base64encode(file("${path.module}/webapp/app.py"))
    apim_url     = "https://${var.provider_apim_gateway_hostname}/model/chat/completions"
    api_resource = "api://${var.provider_api_client_id}"
    web_port     = var.web_port
  }))

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.vm[0].public_key_openssh
  }

  identity {
    type = "SystemAssigned"
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

# Let the VM's managed identity obtain a Model.Invoke token for the provider API.
resource "azuread_app_role_assignment" "vm_model_invoke" {
  count = var.create_test_vm ? 1 : 0

  app_role_id         = var.model_invoke_app_role_id
  principal_object_id = azurerm_linux_virtual_machine.test[0].identity[0].principal_id
  resource_object_id  = azuread_service_principal.provider_api.object_id
}
