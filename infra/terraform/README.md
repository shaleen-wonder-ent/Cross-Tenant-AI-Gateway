# Cross-tenant AI gateway Terraform

This directory contains the shareable Infrastructure as Code for the Private
Link architecture. The deployment is split at the tenant ownership boundary:

| Root | Owner | Resources |
|---|---|---|
| `provider/` | Platform provider | Microsoft Foundry model, APIM, provider VNet, managed identity RBAC, multitenant API registration |
| `customer/` | Customer | Customer VNet, cross-tenant APIM private endpoint, private DNS, client registration, app-role consent |

No tenant IDs, subscription IDs, credentials, plans, or state files are
committed. Each collaborator creates a local `terraform.tfvars` from the
provided example. Use a secured remote backend before multiple people apply
the same root; backend configuration is intentionally environment-specific.

## Prerequisites

- Terraform 1.6 or later
- Azure CLI
- Provider rights to create Azure resources, app registrations, and app roles
- Customer rights to create Azure resources, service principals, and grant
  application consent
- Model quota for the selected model, SKU, capacity, and region

## 1. Deploy the provider root

```powershell
Copy-Item infra/terraform/provider/terraform.tfvars.example infra/terraform/provider/terraform.tfvars
# Edit the local terraform.tfvars values.

az login --tenant <provider-tenant-id>
az account set --subscription <provider-subscription-id>
terraform -chdir=infra/terraform/provider init
terraform -chdir=infra/terraform/provider validate
terraform -chdir=infra/terraform/provider plan -out=tfplan
terraform -chdir=infra/terraform/provider apply tfplan
terraform -chdir=infra/terraform/provider output
```

Copy these provider outputs into the matching customer variables:

- `provider_apim_id`
- `provider_apim_gateway_hostname`
- `provider_api_client_id`
- `model_invoke_app_role_id`

## 2. Deploy the customer root

```powershell
Copy-Item infra/terraform/customer/terraform.tfvars.example infra/terraform/customer/terraform.tfvars
# Edit the local terraform.tfvars values and paste in the provider outputs.

az login --tenant <customer-tenant-id>
az account set --subscription <customer-subscription-id>
terraform -chdir=infra/terraform/customer init
terraform -chdir=infra/terraform/customer validate
terraform -chdir=infra/terraform/customer plan -out=tfplan
terraform -chdir=infra/terraform/customer apply tfplan
```

The private endpoint is created in `Pending` state because the provider owns
APIM. A provider administrator must approve it:

```powershell
az login --tenant <provider-tenant-id>
az account set --subscription <provider-subscription-id>

$connectionId = az network private-endpoint-connection list `
  --id <provider-apim-id> `
  --query "[?properties.privateLinkServiceConnectionState.status=='Pending'].id | [0]" `
  --output tsv

az network private-endpoint-connection approve `
  --id $connectionId `
  --description "Approved customer AI gateway connection"
```

## Client credentials

Terraform creates the customer client application, service principal, and
`Model.Invoke` role assignment, but deliberately does not create a client
secret. Generated secrets are stored in Terraform state. Prefer workload
identity federation for the calling workload, or create and store a credential
through your organization's approved secret-management process.

## Optional test VM

Set `create_test_vm = true` and provide `admin_ssh_public_key` in the customer
variables to create a private, SSH-key-only VM. It has no public IP. Use Azure
Run Command to verify that the APIM hostname resolves to the private endpoint:

```powershell
az vm run-command invoke `
  --resource-group <customer-resource-group> `
  --name <test-vm-name> `
  --command-id RunShellScript `
  --scripts "getent hosts <provider-apim-hostname>"
```

## Optional private APIM-to-Foundry path

The provider root can create the Foundry private endpoint and DNS zones by
setting `enable_foundry_private_endpoint = true`. APIM Standard v2 outbound
VNet integration must also be configured before setting
`foundry_public_network_access_enabled = false`; otherwise APIM cannot reach
the model endpoint.
