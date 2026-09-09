output "provider_apim_id" {
  description = "APIM resource ID consumed by the customer stage."
  value       = azurerm_api_management.this.id
}

output "provider_apim_gateway_hostname" {
  description = "APIM hostname consumed by the customer stage."
  value       = trimsuffix(trimprefix(azurerm_api_management.this.gateway_url, "https://"), "/")
}

output "provider_api_client_id" {
  description = "Multitenant provider API client ID consumed by the customer stage."
  value       = azuread_application.provider_api.client_id
}

output "model_invoke_app_role_id" {
  description = "Model.Invoke app role ID consumed by the customer stage."
  value       = random_uuid.model_invoke_role.result
}

output "provider_api_scope" {
  description = "OAuth scope used by customer client-credentials requests."
  value       = "api://${azuread_application.provider_api.client_id}/.default"
}

output "chat_url" {
  description = "APIM Claude Messages endpoint."
  value       = "${azurerm_api_management.this.gateway_url}/model/v1/messages"
}

output "foundry_endpoint" {
  description = "Microsoft Foundry inference endpoint."
  value       = "https://${azurerm_cognitive_account.foundry.custom_subdomain_name}.services.ai.azure.com"
}

output "model_deployment_name" {
  description = "Deployment name callers pass in the Claude `model` field."
  value       = var.model_deployment_name
}
