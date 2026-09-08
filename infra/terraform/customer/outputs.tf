output "client_app_id" {
  description = "Customer client application ID. Create its credential outside Terraform or add workload identity federation."
  value       = azuread_application.client.client_id
}

output "apim_private_endpoint_ip" {
  description = "Private IP used to reach the provider APIM gateway."
  value       = azurerm_private_endpoint.apim.private_service_connection[0].private_ip_address
}

output "chat_url" {
  description = "Private APIM chat completions URL."
  value       = "https://${var.provider_apim_gateway_hostname}/model/chat/completions"
}

output "test_vm_name" {
  description = "Optional private connectivity test VM name."
  value       = try(azurerm_linux_virtual_machine.test[0].name, null)
}

output "web_url" {
  description = "Demo web page served from the in-VNet VM."
  value       = try("http://${azurerm_public_ip.test[0].ip_address}:${var.web_port}", null)
}

output "test_vm_public_ip" {
  description = "Public IP of the demo VM (locked to your IP by the NSG)."
  value       = try(azurerm_public_ip.test[0].ip_address, null)
}

output "test_vm_ssh_command" {
  description = "SSH into the demo VM using the generated key."
  value       = try("ssh -i infra/terraform/customer/.ssh/${var.prefix}-vm.pem azureuser@${azurerm_public_ip.test[0].ip_address}", null)
}
