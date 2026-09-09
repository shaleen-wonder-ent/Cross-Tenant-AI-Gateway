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
  description = "Foundry catalog model ID to deploy."
  type        = string
  default     = "claude-haiku-4-5"
}

variable "model_deployment_name" {
  description = "Deployment name callers pass in the Claude `model` field."
  type        = string
  default     = "claude-haiku-4-5"
}

variable "model_format" {
  description = "Model publisher/format in the Foundry catalog."
  type        = string
  default     = "Anthropic"
}

variable "model_version" {
  # Confirm the exact Hosted-on-Azure version in the Foundry catalog before applying.
  description = "Foundry model version for the selected hosting option."
  type        = string
  default     = "1"
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

variable "anthropic_version" {
  description = "anthropic-version header APIM sends to the Claude Messages API."
  type        = string
  default     = "2023-06-01"
}

variable "model_industry" {
  description = "Industry for the required Anthropic model provider data."
  type        = string
  default     = "Technology"
}

variable "model_org_name" {
  description = "Organization name for the required Anthropic model provider data."
  type        = string
  default     = "AI Gateway POC"
}

variable "model_country_code" {
  description = "ISO country code for the required Anthropic model provider data."
  type        = string
  default     = "US"
}

variable "app_role_value" {
  description = "Application role required by the APIM policy."
  type        = string
  default     = "Model.Invoke"
}

variable "enable_foundry_private_endpoint" {
  description = "Create a private endpoint and private DNS zones for Foundry."
  type        = bool
  default     = true
}

variable "apim_public_network_access_enabled" {
  description = "Allow public network access to the APIM gateway. Set false to require the cross-tenant private endpoint."
  type        = bool
  default     = true
}

variable "foundry_public_network_access_enabled" {
  description = "Allow public network access to Foundry. Requires APIM outbound VNet integration when false."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to resources that support them."
  type        = map(string)
  default     = {}
}
