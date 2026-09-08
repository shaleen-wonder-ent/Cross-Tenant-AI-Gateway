locals {
  foundry_dns_zones = toset([
    "privatelink.cognitiveservices.azure.com",
    "privatelink.openai.azure.com",
    "privatelink.services.ai.azure.com",
  ])
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "azurerm_resource_group" "this" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.20.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "apim_integration" {
  name                 = "snet-apim-integration"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.20.1.0/24"]

  delegation {
    name = "apim-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.20.2.0/24"]
}

resource "azurerm_cognitive_account" "foundry" {
  name                          = "${var.prefix}-foundry-${random_string.suffix.result}"
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  kind                          = "AIServices"
  sku_name                      = "S0"
  custom_subdomain_name         = "${var.prefix}-foundry-${random_string.suffix.result}"
  local_auth_enabled            = false
  public_network_access_enabled = var.foundry_public_network_access_enabled
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_cognitive_deployment" "model" {
  name                 = var.model_name
  cognitive_account_id = azurerm_cognitive_account.foundry.id

  model {
    format  = "OpenAI"
    name    = var.model_name
    version = var.model_version
  }

  sku {
    name     = var.model_sku_name
    capacity = var.model_capacity
  }
}

resource "azurerm_private_dns_zone" "foundry" {
  for_each = var.enable_foundry_private_endpoint ? local.foundry_dns_zones : toset([])

  name                = each.value
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "foundry" {
  for_each = var.enable_foundry_private_endpoint ? local.foundry_dns_zones : toset([])

  name                  = "link-${replace(each.value, ".", "-")}"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.foundry[each.value].name
  virtual_network_id    = azurerm_virtual_network.this.id
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "foundry" {
  count = var.enable_foundry_private_endpoint ? 1 : 0

  name                = "${var.prefix}-foundry-pe"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "foundry"
    private_connection_resource_id = azurerm_cognitive_account.foundry.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [for zone in azurerm_private_dns_zone.foundry : zone.id]
  }
}

resource "random_uuid" "model_invoke_role" {}

resource "azuread_application" "provider_api" {
  display_name     = "${var.prefix}-model-api"
  sign_in_audience = "AzureADMultipleOrgs"

  app_role {
    allowed_member_types = ["Application"]
    description          = "Allows a client application to invoke the model through APIM."
    display_name         = "Model.Invoke"
    enabled              = true
    id                   = random_uuid.model_invoke_role.result
    value                = var.app_role_value
  }

  lifecycle {
    ignore_changes = [identifier_uris]
  }
}

resource "azuread_application_identifier_uri" "provider_api" {
  application_id = azuread_application.provider_api.id
  identifier_uri = "api://${azuread_application.provider_api.client_id}"
}

resource "azuread_service_principal" "provider_api" {
  client_id = azuread_application.provider_api.client_id
}

resource "azurerm_api_management" "this" {
  name                = "${var.prefix}-apim-${random_string.suffix.result}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = "StandardV2_1"
  tags                = var.tags

  public_network_access_enabled = var.apim_public_network_access_enabled

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "apim_foundry" {
  scope                = azurerm_cognitive_account.foundry.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_api_management.this.identity[0].principal_id
}

resource "azurerm_api_management_api" "model" {
  name                  = "model-api"
  resource_group_name   = azurerm_resource_group.this.name
  api_management_name   = azurerm_api_management.this.name
  revision              = "1"
  display_name          = "Model API"
  path                  = "model"
  protocols             = ["https"]
  subscription_required = false
}

resource "azurerm_api_management_api_operation" "chat" {
  operation_id        = "chat-completions"
  api_name            = azurerm_api_management_api.model.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = azurerm_resource_group.this.name
  display_name        = "Chat Completions"
  method              = "POST"
  url_template        = "/chat/completions"

  response {
    status_code = 200
  }
}

resource "azurerm_api_management_api_policy" "model" {
  api_name            = azurerm_api_management_api.model.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = azurerm_resource_group.this.name

  xml_content = templatefile("${path.module}/policy.xml", {
    api_audience       = "api://${azuread_application.provider_api.client_id}"
    api_version        = var.openai_api_version
    customer_tenant_id = var.customer_tenant_id
    foundry_openai_url = "https://${azurerm_cognitive_account.foundry.custom_subdomain_name}.openai.azure.com/openai/deployments/${azurerm_cognitive_deployment.model.name}"
    role_value         = var.app_role_value
  })
}
