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

Don't let the ISV Platform call Foundry/Anthropic directly with a raw API key baked into the customer environment. Put **Azure API Management (APIM) in front of Foundry, inside the Provider Tenant**, acting as an AI gateway.

The compressed one-line version of the flow (`ISV Platform --HTTPS + OAuth2--> APIM --managed identity--> Foundry --> Anthropic`) hides the one step people usually get stuck on: **where does the OAuth2 token in that first hop actually come from, and who issues it?** The expanded flow below spells that out.

```
CUSTOMER TENANT                                    CROSS-TENANT BOUNDARY                  PROVIDER TENANT
────────────────                                   ──────────────────────                 ───────────────

  End User
    │ signs in with the CUSTOMER's own Entra ID
    │ (app-level authZ only - proves nothing about model access)
    ▼
┌───────────────┐
│ ISV Platform  │
└───────────────┘
    │ (a) BEFORE calling the gateway, the ISV Platform requests its own
    │     app-only access token - a service-to-service call, no user involved:
    │       POST https://login.microsoftonline.com/{PROVIDER-tenant-id}/oauth2/v2.0/token
    │       grant_type=client_credentials, client_id + client_secret
    │     
    │     That client_id/secret was issued by the PROVIDER to THIS client during onboarding, 
    │     and is stored in the CUSTOMER's own Key Vault. It has nothing to do with the end user or the customer's Entra tenant.
    │     
    ▼
    ⇄   Provider Entra ID (token endpoint) - validates the client_id/secret, signs and returns a JWT scoped to the gateway (audience = gateway app)
        
    │
    │ (b) ISV Platform now calls the gateway, presenting that JWT:
    │       HTTPS request, header  Authorization: Bearer <JWT from step a>
    │       over Private Link, or a public endpoint + IP allow-list
    ▼
                                            ═══════════▶
                                                           ┌───────────────────────────────────┐
                                                           │ Azure API Management (v2)         │
                                                           │  validate-jwt checks the JWT's    │
                                                           │  signature / issuer / audience    │
                                                           │  against PROVIDER Entra ID -      │
                                                           │  proves "this is a specific       │
                                                           │  onboarded client", not just      │
                                                           │  anyone on the internet, and      │
                                                           │  resolves the caller to a per-    │
                                                           │  client product/quota             │
                                                           └───────────────────────────────────┘
                                                                       │ (c) authentication-managed-identity:
                                                                       │     APIM's OWN managed identity asks
                                                                       │     PROVIDER Entra ID (SAME tenant)
                                                                       │     for a token scoped to Foundry
                                                                       ▼
                                                           ┌────────────────────────────────┐
                                                           │ Microsoft Foundry              │
                                                           │ Claude deployment              │
                                                           └────────────────────────────────┘
                                                                       │ (d) Foundry's own internal routing to
                                                                       │     Anthropic, billed against the
                                                                       │     PROVIDER's Marketplace subscription -
                                                                       │     not a hop the ISV Platform or APIM
                                                                       │     authenticate separately
                                                                       ▼
                                                           ┌────────────────────────────────┐
                                                           │ Anthropic-operated inference   │
                                                           └────────────────────────────────┘
```

### Four hops, four different credentials — none of them reused across the boundary

| Hop | Credential used | Issued by | What it proves |
|---|---|---|---|
| End User → ISV Platform | Customer Entra ID sign-in | Customer Tenant | This user may use the app. Nothing about model access. |
| **ISV Platform → APIM** (step a+b above) | OAuth2 client-credentials JWT (app-only, or a subscription key) | **Provider Tenant** Entra ID — a service-to-service token, no user identity involved at all | This is a specific client the provider onboarded, entitled to call the gateway. This is the hop people usually assume must be "the user's identity" or "a managed identity" — it's neither. |
| APIM → Foundry (step c) | Managed identity token | Provider Tenant Entra ID (same tenant as APIM) | This call is coming from the provider's own trusted gateway resource. Works because both APIM and Foundry live in the Provider Tenant. |
| Foundry → Anthropic (step d) | None exposed to any caller | Microsoft Foundry's own internal integration | Consumption is billed against the provider's Anthropic Marketplace subscription. Neither the ISV Platform nor APIM ever talk to Anthropic directly. |

The key point to internalize: **step (a) is a pre-flight, app-only token request the ISV Platform makes to the Provider Tenant's Entra ID *before* it ever calls the gateway.** That's the piece that's easy to miss when the flow is compressed to one line — it's what "authenticates" the front-door hop, and it's a completely separate credential from the managed identity APIM later uses to reach Foundry.

See [diagrams/01-solution-architecture-overview.png](../diagrams/01-solution-architecture-overview.png) for the full layered view, [diagrams/02-cross-tenant-request-and-token-flow.png](../diagrams/02-cross-tenant-request-and-token-flow.png) for the numbered, component-level flow, and [diagrams/04-identity-and-token-sequence.png](../diagrams/04-identity-and-token-sequence.png) for the complete 14-step sequence including this token-acquisition step explicitly.

## Why the gateway, specifically

- **The ISV Platform never holds the provider's raw Anthropic/Foundry key.** It authenticates to APIM; APIM holds the real backend credential via managed identity — same tenant, no cross-tenant AAD problem at that hop.
- **Per-client governance.** APIM gives token-quota policies, rate limiting, and token-metering **scoped per client subscription/product**, so usage of shared capacity can be metered and charged back per customer even though everyone shares the provider's Anthropic capacity.
- **Auditability without identity leakage.** The customer's Entra ID/employee claim is passed as a custom header (e.g., `x-user-id`) purely for logging/attribution — it is never used to authenticate against the provider's Foundry resource. The two identity domains stay separate.
- **Swap-ready.** If a client later moves to their own Anthropic contract (Option B, see [docs/04-commercial-models.md](04-commercial-models.md)), only the ISV Platform's backend endpoint changes — the calling pattern ("call a gateway") stays the same.

## Read next

- [docs/02-identity-and-trust-boundary.md](02-identity-and-trust-boundary.md) for exactly how identity is split front-door vs. back-door
- [docs/03-networking-and-private-link.md](03-networking-and-private-link.md) for the connectivity mechanics
- [docs/06-implementation-runbook.md](06-implementation-runbook.md) to start building
