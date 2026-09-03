# 4. Commercial Models: Option A vs. Option B

Two ways to deliver Claude-via-Foundry to a client, sharing the same application and gateway pattern — only the backend endpoint and the billing owner change.

## Option A — Provider-owned Foundry (pilot / service delivery)

The provider's own Anthropic contract and Marketplace subscription sit in the **Provider Tenant**. The client's ISV Platform reaches it cross-tenant through the gateway described in this repo.

- Fast to stand up per client — no new procurement per engagement.
- Single relationship for the provider with better volume-pricing leverage (subject to reconfirming pricing — see [docs/07-constraints-and-open-risks.md](07-constraints-and-open-risks.md)).
- Central governance: one gateway, one place to apply quota/rate-limit/content-safety policy across all clients.
- **Watch-outs:**
  - Customer prompts/completions leave the customer's tenant and geography — this needs an explicit data-processing agreement, not just an architecture sign-off.
  - The provider carries the consumption cost and scaling risk as more clients onboard, recovered through the service fee.
  - Regional availability is a hard product constraint, not a contract question — reconfirm current supported regions before assuming a specific data residency is available.

## Option B — Customer-owned Foundry (production / scale)

The client provisions **their own** Foundry account, Claude deployment, and Anthropic Marketplace subscription (via a private offer) inside their **own tenant/subscription**. The ISV Platform (still the provider's code) runs and calls Foundry entirely **within the customer's own tenant** — no cross-tenant identity or networking problem at all.

- Cleanest isolation: no cross-tenant boundary to design around.
- Customer owns billing, compliance, and data residency decisions directly.
- **The provider is not cut out of the deal** — compensation continues via a **multiparty private offer**, with Microsoft paying the provider directly as channel partner. This reframes the con from "provider loses the deal" to "provider is compensated differently."
- **Watch-outs:**
  - Requires per-client procurement — slower to onboard than Option A.
  - **CSP subscriptions are not universally supported** for every Anthropic-on-Foundry offer. Confirm support for the specific model/deployment type before assuming Option B is available — if the client's subscription is CSP and the offer doesn't support it, Option B is off the table for that client until resolved.

## Decision guidance

| Situation | Suggested option |
|---|---|
| Pilot / proof of concept, speed matters, data sensitivity is low | **Option A** |
| Regulated industry, strict data residency requirements, or client demands full isolation | **Option B** (subject to CSP/region support) |
| Production, high volume, long-term engagement | **Option B** as the default target — start on Option A if needed, migrate later (the gateway pattern makes this a backend-swap, not a rebuild) |
| Client is on a CSP subscription | Confirm CSP support for the specific model offer **before** proposing Option B |

See [diagrams/05-commercial-options-comparison.png](../diagrams/05-commercial-options-comparison.png) for the side-by-side flow, and [docs/07-constraints-and-open-risks.md](07-constraints-and-open-risks.md) for the full list of things to reconfirm before a client commitment.
