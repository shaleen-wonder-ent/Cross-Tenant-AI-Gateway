# 1. Architecture Overview

## The scenario

A platform provider delivers an application (the "ISV Platform") to end customers. That application does model routing and calls Anthropic's Claude models — but through **Microsoft Foundry using the provider's own Anthropic contract and keys**, not the customer's. The twist: the application itself is deployed **inside the customer's own Azure tenant / VNet** (their private cloud), not the provider's.

That creates a genuine cross-tenant relationship:

- **Customer Tenant** — owns the application's compute, the customer's Entra ID (used for app sign-in), and the customer's network.
- **Provider Tenant** — owns the Microsoft Foundry resource, the Claude model deployment, and the Anthropic Marketplace subscription that the contract and billing sit under.

Some users of the application are the provider's own staff, but they sign in using **customer** Entra IDs (guest-style or customer-issued accounts), not the provider's identity. That's a red herring for the architecture — it only affects who can use the app, not how the app authenticates to the model.

## Is it viable?

**Yes — as long as the cross-tenant hop uses key/token-based auth, not Entra-ID/managed-identity trust.**

Two facts make this work:

1. Key-based or OAuth2-client-credentials calls over HTTPS have **no tenant restriction**. This is architecturally identical to any app calling an external SaaS API (e.g., calling a third-party REST API with an API key) — tenancy is irrelevant to that trust model.
2. Azure Private Link explicitly supports **cross-tenant private endpoint connections** via an approval workflow — a consumer resource in one tenant can connect to a provider resource in another tenant with no VPN or VNet peering required. NAT is applied automatically, so overlapping private IP ranges across many customer VNets never collide at the provider side.

What does **not** work, and shouldn't be attempted: using a managed identity from the Customer Tenant to directly authenticate against a Foundry resource in the Provider Tenant. Managed identities are tenant-bound; there's no federation path across tenants for them.

## The recommended shape

Don't let the ISV Platform call Foundry/Anthropic directly with a raw API key baked into the customer environment. Put **Azure API Management (APIM) in front of Foundry, inside the Provider Tenant**, acting as an AI gateway:

```
Customer Tenant                    Cross-Tenant Boundary                  Provider Tenant
────────────────                   ──────────────────────                 ───────────────
ISV Platform  ──HTTPS + OAuth2──▶  Private Link (or public+allow-list) ──▶ Azure API Management (v2 tier)
                                                                                │  authentication-managed-identity
                                                                                ▼  (same-tenant hop)
                                                                           Microsoft Foundry — Claude deployment
                                                                                │
                                                                                ▼
                                                                           Anthropic-operated inference
```

See [diagrams/01-solution-architecture-overview.drawio](../diagrams/01-solution-architecture-overview.drawio) for the full layered view and [diagrams/02-cross-tenant-request-and-token-flow.drawio](../diagrams/02-cross-tenant-request-and-token-flow.drawio) for the numbered, component-level flow.

## Why the gateway, specifically

- **The ISV Platform never holds the provider's raw Anthropic/Foundry key.** It authenticates to APIM; APIM holds the real backend credential via managed identity — same tenant, no cross-tenant AAD problem at that hop.
- **Per-client governance.** APIM gives token-quota policies, rate limiting, and token-metering **scoped per client subscription/product**, so usage of shared capacity can be metered and charged back per customer even though everyone shares the provider's Anthropic capacity.
- **Auditability without identity leakage.** The customer's Entra ID/employee claim is passed as a custom header (e.g., `x-user-id`) purely for logging/attribution — it is never used to authenticate against the provider's Foundry resource. The two identity domains stay separate.
- **Swap-ready.** If a client later moves to their own Anthropic contract (Option B, see [docs/04-commercial-models.md](04-commercial-models.md)), only the ISV Platform's backend endpoint changes — the calling pattern ("call a gateway") stays the same.

## Read next

- [docs/02-identity-and-trust-boundary.md](02-identity-and-trust-boundary.md) for exactly how identity is split front-door vs. back-door
- [docs/03-networking-and-private-link.md](03-networking-and-private-link.md) for the connectivity mechanics
- [docs/06-implementation-runbook.md](06-implementation-runbook.md) to start building
