# Recording steps — Cross-Tenant AI Gateway demo

> Temporary file for the walkthrough recording. Delete when done.
> All names/IDs below are from the current deployment.

## Deployed resources (this session)

| Side | Item | Value |
|---|---|---|
| Customer | Tenant | `89b9a646-a638-487d-809c-4513afcb12e9` (demoshaleet.onmicrosoft.com) |
| Customer | Subscription | `089e068e-38d9-42db-a644-d3d242fc31e1` (Pay-As-You-Go) |
| Customer | Resource group | `aigw-cust-rg` |
| Customer | Web page (VM) | http://172.176.159.238:5000 |
| Customer | VM | `aigw-cust-test-vm` (system-assigned managed identity) |
| Customer | Client app registration | `aigw-cust-client` — `ebf62717-f023-4f2a-8142-ff338e3d2483` |
| Customer | Provider API (enterprise app) | `aigw-prov-model-api` — SP `191757d3-2478-4a0f-a031-49f3b5111c7f` |
| Customer | Private endpoint | `aigw-cust-apim-pe` → `10.10.1.4` |
| Customer | Private DNS zone | `privatelink.azure-api.net` |
| Provider | Tenant | `d832042c-0b39-4a9a-91f8-ef2b60153a96` (shaleenthapahotmail.onmicrosoft.com) |
| Provider | Subscription | `20f97081-6301-493e-a180-d9ee966c3c01` (VS Enterprise) |
| Provider | Resource group | `aigw-prov-rg` |
| Provider | APIM (private-only) | `aigw-prov-apim-vevwn` |
| Provider | API app (multitenant) | `aigw-prov-model-api` — `c3bacd9c-5cf2-4ba4-9467-df25d0d23932` |
| Provider | App role | `Model.Invoke` — `7e026c83-25da-748c-eb20-c31fc709112b` |
| Provider | Foundry | `aigw-prov-foundry-vevwn` — model `gpt-4o` |
| Provider | Gateway URL | https://aigw-prov-apim-vevwn.azure-api.net/model/chat/completions |

---

## The auth flow (say this out loud)

```mermaid
sequenceDiagram
    participant U as User (browser)
    participant VM as Customer VM web app<br/>(managed identity)
    participant CE as Customer Entra ID
    participant PE as Private endpoint 10.10.1.4
    participant AP as Provider APIM (private)
    participant PE2 as APIM managed identity
    participant F as Foundry gpt-4o

    U->>VM: Enter prompt, submit
    VM->>CE: Get token (IMDS) for api://c3bacd9c... 
    CE-->>VM: JWT (iss=customer tenant, roles=[Model.Invoke])
    VM->>PE: POST /model/chat/completions + Bearer JWT
    PE->>AP: private link (no public path)
    AP->>AP: validate-azure-ad-token:<br/>tenant=customer, audience=api://c3bacd9c, role=Model.Invoke
    AP->>PE2: authentication-managed-identity
    PE2-->>AP: token for cognitiveservices.azure.com
    AP->>F: forward request (APIM identity + RBAC)
    F-->>AP: completion
    AP-->>VM: response
    VM-->>U: render answer
```

**Who authenticates whom — one line each:**
1. **Customer Entra authenticates the VM** — issues a token to the VM's managed identity.
2. The token carries **`Model.Invoke`** because that role was granted to the VM identity on the provider API's enterprise app **in the customer tenant**.
3. **Provider APIM authenticates the caller** — the policy validates the customer-tenant JWT (issuer, audience, role) before doing anything.
4. **APIM authenticates itself to Foundry** — using APIM's own managed identity (provider tenant) + RBAC role `Cognitive Services OpenAI User`. No keys (Foundry local auth is disabled).
5. Nothing crosses the tenant boundary except the JWT + HTTPS over Private Link. The Foundry endpoint/keys never leave the provider tenant.

---

## PART 1 — Customer tenant (sign in as `shaleenthapa@demoshaleet.onmicrosoft.com`)

### 1. Show the working demo
- Open **http://172.176.159.238:5000**
- Type a prompt, click **Send through gateway**, show the `gpt-4o` answer.
- Narrate: "This page runs inside the customer VNet. It never sees a key — it uses the VM's managed identity."

### 2. The calling identity (client app registration)
- Portal → **Microsoft Entra ID → App registrations → `aigw-cust-client`**
- **API permissions** blade → show **`Model.Invoke`** (Application permission) on `aigw-prov-model-api`, status **Granted**.
- Narrate: "This is the customer-owned app that is allowed to call the provider's API."

### 3. The app-role grant (this is the consent)
- **Microsoft Entra ID → Enterprise applications → `aigw-prov-model-api`**
- **Users and groups** (or **Application** → app role assignments) → show the **VM managed identity** and the **client SP** assigned **`Model.Invoke`**.
- Narrate: "The provider's API exists here as an enterprise app. We granted the VM's identity the Model.Invoke role — that's what puts the role into the token."

### 4. The compute + private path
- Portal → **Resource groups → `aigw-cust-rg`**
- **`aigw-cust-test-vm` → Identity** → show **System assigned = On**. "This identity is the caller."
- **`aigw-cust-apim-pe`** (private endpoint) → **Connection state = Approved**, private IP **10.10.1.4**.
- **`privatelink.azure-api.net`** (private DNS zone) → Recordsets → A record for `aigw-prov-apim-vevwn` → **10.10.1.4**.
- Narrate: "The gateway hostname resolves to a private IP inside our VNet. There is no public route."

### 5. (Optional) prove it on the VM
```powershell
ssh -i infra/terraform/customer/.ssh/aigw-cust-vm.pem azureuser@172.176.159.238 `
  "getent hosts aigw-prov-apim-vevwn.azure-api.net; sudo journalctl -u aigw --no-pager | tail -n 20"
```
- Show the hostname resolves to `10.10.1.4` and the app log shows a 200.

---

## PART 2 — Provider tenant (sign in as `shaleenthapa@shaleenthapahotmail.onmicrosoft.com`)

### 6. The API definition (multitenant + the role)
- Portal → **Microsoft Entra ID → App registrations → `aigw-prov-model-api`**
- **App roles** blade → show **`Model.Invoke`** (Allowed member types: Applications).
- **Authentication / Overview** → note **Supported account types = multitenant** (`AzureADMultipleOrgs`).
- Narrate: "This is the provider's API. It's multitenant so the customer tenant can consent to it."

### 7. The gateway policy (the actual authentication)
- Portal → **Resource groups → `aigw-prov-rg` → `aigw-prov-apim-vevwn` (API Management)**
- **APIs → Model API → Design → Inbound processing → `</>` (code view)**. Show:
  - `validate-azure-ad-token` with `tenant-id` = customer tenant, `audience` = `api://c3bacd9c...`, required claim `roles` = `Model.Invoke`.
  - `authentication-managed-identity resource="https://cognitiveservices.azure.com"`.
  - `set-backend-service` → Foundry deployment URL.
- Narrate: "Step 1 authenticates the customer's token. Step 2 swaps in APIM's own identity for Foundry."

### 8. APIM is private + identity
- APIM → **Network** → **Public network access = Disabled**; **Private endpoint connections** → the customer connection **Approved**.
- APIM → **Managed identities** → **System assigned = On**.
- Narrate: "The gateway has no public access. Inbound is only via the approved private endpoint."

### 9. Foundry authorizes APIM (no keys)
- Resource group `aigw-prov-rg` → **`aigw-prov-foundry-vevwn`**
- **Access control (IAM) → Role assignments** → show **`Cognitive Services OpenAI User`** granted to **`aigw-prov-apim-vevwn`** (APIM identity).
- **Resource Management → Keys and Endpoint** → note key auth is disabled (local auth off).
- **Model deployments** → show **`gpt-4o`**.
- Narrate: "Foundry trusts APIM by RBAC, not a key. The provider's model access never leaves this tenant."

---

## Suggested recording order (fastest)
1. Part 1 → step 1 (show it working), then steps 2–4 (customer identity + private path).
2. Part 2 → steps 6–9 (provider API, policy, private APIM, Foundry RBAC).
3. Close on the mermaid flow: "customer identity in, provider identity to the model, private link between — no shared secrets."

## Cleanup after recording
```powershell
az account set --subscription 089e068e-38d9-42db-a644-d3d242fc31e1
terraform -chdir=infra/terraform/customer destroy
az account set --subscription 20f97081-6301-493e-a180-d9ee966c3c01
terraform -chdir=infra/terraform/provider destroy
```
