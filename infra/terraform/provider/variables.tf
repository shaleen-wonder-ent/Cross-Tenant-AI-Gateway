variable "tenant_id" {
  description = "Tenant ID that hosts APIM and Microsoft Foundry."
  type        = string
}

variable "subscription_id" {
  description = "Subscription ID that hosts APIM and Microsoft Foundry."
  type        = string
}

variable "customer_tenant_id" {
  description = "Customer tenant whose access tokens APIM accepts."
  type        = string
}

variable "location" {
  description = "Azure region for provider resources."
  type        = string
  default     = "eastus2"
}

variable "prefix" {
  description = "Naming prefix for provider resources."
  type        = string
  default     = "aigw-prov"
}

variable "publisher_name" {
  description = "APIM publisher name."
  type        = string
}

variable "publisher_email" {
  description = "APIM publisher email."
  type        = string
}

variable "model_name" {
  description = "Foundry model name and deployment name."
  type        = string
  default     = "gpt-4o"
}

variable "model_version" {
  description = "Foundry model version available in the selected region."
  type        = string
  default     = "2024-11-20"
}

variable "model_sku_name" {
  description = "Foundry model deployment SKU."
  type        = string
  default     = "GlobalStandard"
}

variable "model_capacity" {
  description = "Foundry model deployment capacity in thousands of tokens per minute."
  type        = number
  default     = 10

  validation {
    condition     = var.model_capacity > 0
    error_message = "model_capacity must be greater than zero."
  }
}

variable "openai_api_version" {
  description = "API version APIM passes to the Foundry model endpoint."
  type        = string
  default     = "2024-10-21"
}

variable "app_role_value" {
  description = "Application role required by the APIM policy."
  type        = string
  default     = "Model.Invoke"
}

variable "enable_foundry_private_endpoint" {
  description = "Create a private endpoint and private DNS zones for Foundry."
  type        = bool
  default     = false
}

variable "foundry_public_network_access_enabled" {
  description = "Allow public network access to Foundry. Disable only after APIM outbound VNet integration is configured."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to resources that support them."
  type        = map(string)
  default     = {}
}
