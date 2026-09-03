# Cross-Tenant AI Gateway Cookbook — Consuming Anthropic Models via Microsoft Foundry Across Tenants

This repository documents a validated architecture for a common ISV/SI pattern:

> An application runs **inside an end-customer's Azure tenant**, but the underlying LLM (Anthropic's Claude models via Microsoft Foundry) is consumed from a **different tenant** — the platform provider's own Azure/EA tenant — because that's where the provider's Anthropic contract and API keys live.

> **Naming convention used throughout this repo:** 
"Customer Tenant" = the end-customer's Azure/Entra tenant where the application runs. 
"Provider Tenant" = the platform provider's own Azure/EA tenant that owns the Anthropic-on-Foundry Marketplace subscription. 
"ISV Platform" = the application/model-routing layer being delivered to the customer.

## Start here

**[docs/00-first-call-discussion-guide.md](docs/00-first-call-discussion-guide.md)** — the material for the first-level architecture discussion with a customer: the two front-door implementation options (OAuth2 client-credentials vs. APIM subscription key), the network-design conversation (no VNet peering allowed, Private Link vs. public endpoint), and the challenges to raise proactively (cross-region latency and connectivity, most notably).

## The one rule that makes this architecture work

**Managed identity does not work across Entra tenants.** An app running in the Customer Tenant cannot use a system/user-assigned managed identity to get a token for a Foundry resource that lives in the Provider Tenant — there is no cross-tenant federation path for managed identities.

The fix is **not** to force Entra ID across the boundary. It's to **terminate identity at the gateway**:

- **Front door** (Customer Tenant → Provider Tenant): OAuth2 client-credentials (Option 1) or an APIM subscription key (Option 2), over HTTPS. Either has no tenant restriction — it's the same shape as calling any external SaaS API.
- **Back door** (gateway → Foundry): `authentication-managed-identity`, because this hop is same-tenant, which is exactly where managed identity works.

Everything else in this repo follows from that one rule.

## Repository map

```
docs/                     Phase 1 - first customer call: architecture, identity, networking, challenges
diagrams/                 Phase 1 diagrams - 7 draw.io architecture diagrams
phase-2-implementation/   Phase 2 - after the customer picks a direction: commercial model, APIM policy config, build runbook
```

## Diagrams (Phase 1)

| # | File | What it shows |
|---|------|----------------|
| 1 | [diagrams/01-solution-architecture-overview.png](diagrams/01-solution-architecture-overview.png) | Full-picture grid: identity, network, AI platform, commercial, and governance layers across the three zones. |
| 2 | [diagrams/02-cross-tenant-request-and-token-flow.png](diagrams/02-cross-tenant-request-and-token-flow.png) | Detailed, numbered (1–10) component flow from end user to Anthropic and back to billing. |
| 3 | [diagrams/03-networking-and-private-link.png](diagrams/03-networking-and-private-link.png) | Network-level detail: VNets, subnets, NSGs, cross-tenant Private Endpoint approval workflow, DNS, NAT behavior, and the public-endpoint alternative. |
| 4 | [diagrams/04-identity-and-token-sequence.png](diagrams/04-identity-and-token-sequence.png) | Actor-by-actor sequence diagram (14 steps) showing exactly which credential is used at each hop. |
| 5 | [diagrams/05-animated-call-flow.png](diagrams/05-animated-call-flow.png) | Simplified live-call diagram with animated (pulsing) edges showing request, response, and async metering paths in real time. |
| 6 | [diagrams/06-two-options-call-flow.png](diagrams/06-two-options-call-flow.png) | **Main diagram for the first call.** Option 1 (OAuth2) vs. Option 2 (subscription key) shown as alternative front-door paths into the same gateway. |
| 7 | [diagrams/07-network-architecture.png](diagrams/07-network-architecture.png) | **Main diagram for the first call.** Customer → APIM → Foundry → Anthropic, the no-peering constraint, and both connectivity paths. |

Each PNG has an editable `.drawio` source of the same name in the same folder — open that in draw.io to modify it.

See [docs/05-diagrams-index.md](docs/05-diagrams-index.md) for how to open and animate the editable sources.

> The commercial-options diagram (Option A provider-owned Foundry vs. Option B customer-owned Foundry) now lives in [phase-2-implementation/diagrams/](phase-2-implementation/diagrams/) — it's a later-stage conversation, separate from the Option 1/Option 2 front-door choice above.

## Docs (Phase 1 — read in order)

0. [docs/00-first-call-discussion-guide.md](docs/00-first-call-discussion-guide.md) — **start here.** The two front-door options, network design, and challenges to bring to the first customer call
1. [docs/01-architecture-overview.md](docs/01-architecture-overview.md) — the scenario, the viability call, and the recommended shape
2. [docs/02-identity-and-trust-boundary.md](docs/02-identity-and-trust-boundary.md) — why managed identity fails cross-tenant, and the front-door/back-door split
3. [docs/03-networking-and-private-link.md](docs/03-networking-and-private-link.md) — connectivity options, cross-tenant Private Link mechanics, and why VNet peering isn't the right tool
4. [docs/04-constraints-and-open-risks.md](docs/04-constraints-and-open-risks.md) — cross-region latency and connectivity challenges to raise proactively, plus data residency and cross-tenant audit considerations
5. [docs/05-diagrams-index.md](docs/05-diagrams-index.md) — how to open, edit, and animate the diagrams

## Phase 2 — after the customer picks a direction

Once the first call has landed on a front-door option and a connectivity path, move to **[phase-2-implementation/](phase-2-implementation/)** for:

- Commercial model (Option A provider-owned Foundry vs. Option B customer-owned Foundry — a separate decision from Option 1/2 above)
- Concrete APIM policy XML and SKU requirements
- The step-by-step implementation runbook

## What this repo does **not** claim

Regional availability, CSP support, and discount/billing terms for Anthropic models on Microsoft Foundry change over time and are commercial facts, not architecture facts. Every place this repo references them, it's flagged as **"reconfirm with your account team"** rather than stated as permanent truth. Don't quote this repo as the source of record for pricing, region lists, or contract terms — validate those independently before a client commitment.
