# Cross-Tenant AI Gateway Cookbook — Consuming Anthropic Models via Microsoft Foundry Across Tenants

This repository documents a validated architecture for a common ISV/SI pattern:

> An application runs **inside an end-customer's Azure tenant**, but the underlying LLM (Anthropic's Claude models via Microsoft Foundry) is consumed from a **different tenant** — the platform provider's own Azure/EA tenant — because that's where the provider's Anthropic contract and API keys live.

It answers three questions:

1. **Is this viable?** Yes, with one hard architectural rule (see below) and a short list of commercial/regulatory constraints to validate per client.
2. **How do you build it?** Azure API Management (APIM) as an AI gateway, deployed in the provider's tenant, in front of Microsoft Foundry — the application never talks to Foundry directly.
3. **What are the options as a client scales to production?** Keep using the provider's shared Anthropic capacity (Option A) vs. the client provisioning their own Anthropic contract via Azure Marketplace (Option B).

> **Naming convention used throughout this repo:** no company names are used. "Customer Tenant" = the end-customer's Azure/Entra tenant where the application runs. "Provider Tenant" = the platform provider's own Azure/EA tenant that owns the Anthropic-on-Foundry Marketplace subscription. "ISV Platform" = the application/model-routing layer being delivered to the customer.

## The one rule that makes this architecture work

**Managed identity does not work across Entra tenants.** An app running in the Customer Tenant cannot use a system/user-assigned managed identity to get a token for a Foundry resource that lives in the Provider Tenant — there is no cross-tenant federation path for managed identities.

The fix is **not** to force Entra ID across the boundary. It's to **terminate identity at the gateway**:

- **Front door** (Customer Tenant → Provider Tenant): OAuth2 client-credentials (preferred) or an APIM subscription key, over HTTPS. This has no tenant restriction — it's the same shape as calling any external SaaS API.
- **Back door** (gateway → Foundry): `authentication-managed-identity`, because this hop is same-tenant, which is exactly where managed identity works.

Everything else in this repo follows from that one rule.

## Repository map

```
diagrams/   6 draw.io architecture diagrams (open with the draw.io VS Code extension, desktop app, or app.diagrams.net)
docs/       The cookbook - narrative explanation, runbook, and constraints
policies/   Ready-to-adapt Azure API Management policy XML for the gateway
```

## Diagrams

| # | File | What it shows |
|---|------|----------------|
| 1 | [diagrams/01-solution-architecture-overview.drawio](../diagrams/01-solution-architecture-overview.drawio) | Full-picture grid: identity, network, AI platform, commercial, and governance layers across the three zones (Customer Tenant / Cross-Tenant Boundary / Provider Tenant). Start here. |
| 2 | [diagrams/02-cross-tenant-request-and-token-flow.drawio](../diagrams/02-cross-tenant-request-and-token-flow.drawio) | Detailed, numbered (1–10) component flow from end user to Anthropic and back to billing. |
| 3 | [diagrams/03-networking-and-private-link.drawio](../diagrams/03-networking-and-private-link.drawio) | Network-level detail: VNets, subnets, NSGs, cross-tenant Private Endpoint approval workflow, DNS, NAT behavior, and the public-endpoint alternative. |
| 4 | [diagrams/04-identity-and-token-sequence.drawio](../diagrams/04-identity-and-token-sequence.drawio) | Actor-by-actor sequence diagram (14 steps) showing exactly which credential is used at each hop. |
| 5 | [diagrams/05-commercial-options-comparison.drawio](../diagrams/05-commercial-options-comparison.drawio) | Option A (provider-owned Foundry) vs. Option B (customer-owned Foundry) side by side, including the billing and contracting differences. |
| 6 | [diagrams/06-animated-call-flow.drawio](../diagrams/06-animated-call-flow.drawio) | Simplified live-call diagram with animated (pulsing) edges showing request, response, and async metering paths in real time. |

See [docs/08-diagrams-index.md](../docs/08-diagrams-index.md) for how to open and animate them.

## Docs (read in order)

1. [docs/01-architecture-overview.md](../docs/01-architecture-overview.md) — the scenario, the viability call, and the recommended shape
2. [docs/02-identity-and-trust-boundary.md](../docs/02-identity-and-trust-boundary.md) — why managed identity fails cross-tenant, and the front-door/back-door split
3. [docs/03-networking-and-private-link.md](../docs/03-networking-and-private-link.md) — connectivity options and cross-tenant Private Link mechanics
4. [docs/04-commercial-models.md](../docs/04-commercial-models.md) — Option A vs Option B, and when each applies
5. [docs/05-apim-gateway-configuration.md](../docs/05-apim-gateway-configuration.md) — concrete policy XML, SKU requirements, and setup steps
6. [docs/06-implementation-runbook.md](../docs/06-implementation-runbook.md) — step-by-step build checklist
7. [docs/07-constraints-and-open-risks.md](../docs/07-constraints-and-open-risks.md) — things to reconfirm with your Microsoft/Anthropic account team before committing to a client
8. [docs/08-diagrams-index.md](../docs/08-diagrams-index.md) — how to open, edit, and animate the diagrams

## What this repo does **not** claim

Regional availability, CSP support, and discount/billing terms for Anthropic models on Microsoft Foundry change over time and are commercial facts, not architecture facts. Every place this repo references them, it's flagged as **"reconfirm with your account team"** rather than stated as permanent truth. Don't quote this repo as the source of record for pricing, region lists, or contract terms — validate those independently before a client commitment.
