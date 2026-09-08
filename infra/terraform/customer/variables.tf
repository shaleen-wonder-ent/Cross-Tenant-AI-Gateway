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

variable "create_test_vm" {
  description = "Create an SSH-only VM for validating private DNS and connectivity."
  type        = bool
  default     = false
}

variable "admin_ssh_public_key" {
  description = "SSH public key used when create_test_vm is true."
  type        = string
  default     = ""

  validation {
    condition     = !var.create_test_vm || trimspace(var.admin_ssh_public_key) != ""
    error_message = "admin_ssh_public_key is required when create_test_vm is true."
  }
}

variable "tags" {
  description = "Tags applied to resources that support them."
  type        = map(string)
  default     = {}
}
