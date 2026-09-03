# 6. Implementation Runbook

Step-by-step checklist to stand up the architecture described in this repo. Each phase links back to the relevant doc/diagram.

## Phase 0 — Decide the commercial model per client

- [ ] Confirm with the client whether Option A (provider-owned Foundry) or Option B (customer-owned Foundry) applies — see [docs/04-commercial-models.md](04-commercial-models.md)
- [ ] If Option B: confirm the client's subscription type supports the Anthropic-on-Foundry offer (CSP is not universally supported — reconfirm at deployment time)
- [ ] If Option A: confirm data residency requirements against currently supported Foundry/Claude regions, and get a data-processing agreement in place before any customer data flows cross-tenant
- [ ] Reconfirm current Anthropic/Foundry consumption pricing with your account team — existing volume discounts do not automatically carry over to consumption-based (CCU) billing

## Phase 1 — Provider Tenant: Foundry and the model

- [ ] Provision (or reuse) a Microsoft Foundry account + project in the Provider Tenant, one project per customer engagement
- [ ] Deploy the Claude model (confirm supported deployment type/region at deployment time)
- [ ] Disable public network access on the Foundry account once the same-tenant private endpoint from APIM is in place

## Phase 2 — Provider Tenant: the gateway

- [ ] Provision Azure API Management on a **v2 tier** (required for Anthropic Messages API token policies — see [docs/05-apim-gateway-configuration.md](05-apim-gateway-configuration.md))
- [ ] Integrate APIM with Application Insights; enable custom metrics with dimensions
- [ ] Create the backend pointing at the Foundry Claude deployment; grant the APIM managed identity the `Cognitive Services User` role on that Foundry resource
- [ ] Register a multi-tenant Entra ID application (once) for OAuth2 client-credentials issuance, if using that front-door option instead of subscription keys
- [ ] Apply the inbound/outbound policy from [policies/gateway-inbound-policy.xml](../policies/gateway-inbound-policy.xml), adapting tenant id, audience, issuer, and backend id
- [ ] Create a per-client product/subscription (or app registration + admin consent, for OAuth2) for each onboarding client

## Phase 3 — Connectivity

- [ ] Decide per client: cross-tenant Private Link, or public endpoint + IP allow-list (see [docs/03-networking-and-private-link.md](03-networking-and-private-link.md))
- [ ] If Private Link: create the private endpoint in the Customer VNet targeting the APIM Private Link service; agree an approval process for the connection request
- [ ] Configure Private DNS zone linking on the customer side so the gateway FQDN resolves privately
- [ ] Lock down NSGs on the customer side to only the intended gateway endpoint

## Phase 4 — Application (Customer Tenant)

- [ ] Store the client credential (OAuth2 client secret/certificate, or subscription key) in the customer's own Key Vault, scoped to this client only
- [ ] Confirm the ISV Platform never holds a raw Foundry/Anthropic key — only the gateway credential
- [ ] Wire the customer Entra ID user claim through as an `x-user-id` header for attribution only — verify it is never used by any authorization check against the Provider Tenant
- [ ] Point the ISV Platform's model-routing config at the gateway endpoint (private or public, per Phase 3)

## Phase 5 — Test and validate

- [ ] Run the test call from [docs/05-apim-gateway-configuration.md](05-apim-gateway-configuration.md) end to end
- [ ] Confirm token-limit headers are returned and quota is enforced per client (test by exceeding the configured `tokens-per-minute`)
- [ ] Confirm `Total Tokens` / `Prompt Tokens` / `Completion Tokens` custom metrics appear in Application Insights, dimensioned by `ClientId`
- [ ] Confirm revocation works: disable a client's credential/subscription and verify the next call is rejected with 401/403
- [ ] Run a joint walkthrough with the client covering [diagrams/06-animated-call-flow.png](../diagrams/06-animated-call-flow.png) so the request/response/metering paths are visually clear

## Phase 6 — Ongoing operations

- [ ] Monitor Azure Monitor custom-metric limits (100 values per dimension, 1,000 active time series per namespace/region) as more clients are onboarded
- [ ] Revisit Phase 0 constraints (region, CSP, pricing) periodically — they are commercial facts that can change independently of the architecture
- [ ] Keep an explicit path to migrate a client from Option A to Option B: only the backend endpoint and credential change, the application-level integration does not
