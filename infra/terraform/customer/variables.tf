variable "tenant_id" {
  description = "Customer tenant ID."
  type        = string
}

variable "subscription_id" {
  description = "Customer subscription ID."
  type        = string
}

variable "location" {
  description = "Azure region for customer resources."
  type        = string
  default     = "eastus2"
}

variable "prefix" {
  description = "Naming prefix for customer resources."
  type        = string
  default     = "aigw-cust"
}

variable "provider_apim_id" {
  description = "Provider APIM resource ID from the provider Terraform output."
  type        = string
}

variable "provider_apim_gateway_hostname" {
  description = "Provider APIM gateway hostname from the provider Terraform output."
  type        = string
}

variable "provider_api_client_id" {
  description = "Provider API application client ID from the provider Terraform output."
  type        = string
}

variable "model_invoke_app_role_id" {
  description = "Model.Invoke role ID from the provider Terraform output."
  type        = string
}

variable "model_deployment_name" {
  description = "Claude deployment name from the provider, sent in the request `model` field."
  type        = string
  default     = "claude-haiku-4-5"
}

variable "create_test_vm" {
  description = "Create an in-VNet VM that serves the demo web page and calls APIM privately."
  type        = bool
  default     = false
}

variable "web_port" {
  description = "TCP port the demo web app listens on."
  type        = number
  default     = 5000
}

variable "vm_size" {
  description = "VM size for the demo web app. Choose a family with available quota in the subscription."
  type        = string
  default     = "Standard_B2s"
}

variable "allowed_client_ip" {
  description = "Public IP allowed to reach SSH and the web app. Empty auto-detects the caller's IP."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to resources that support them."
  type        = map(string)
  default     = {}
}
