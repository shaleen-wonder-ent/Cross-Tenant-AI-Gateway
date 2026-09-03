# 7. Constraints and Open Risks

This is the list of things that are **commercial, contractual, or regional facts**, not architecture facts. The architecture in this repo is valid regardless of how these resolve — but each one can determine whether Option A or Option B is even available for a given client, or whether a client's data-residency requirement can be met at all. Reconfirm all of these with your Microsoft and Anthropic account teams before making a commitment to a client; they change over time and are not something this repo can certify.

## 1. Data residency is a product constraint, not just a legal one

A data-processing agreement can cover the legal/contractual side of customer data leaving the customer's tenant, but it cannot manufacture a deployment region that doesn't exist. If a client requires in-country data residency and the current Claude-on-Foundry offering doesn't support a country-local deployment, no amount of contractual cover changes that — the deployment simply cannot meet the requirement as architected. Confirm the current supported region/data-zone list before any client conversation about residency.

## 2. CSP support is not guaranteed for every model offer

If the end-customer's subscription is Cloud Solution Provider (CSP), confirm whether the specific Anthropic-on-Foundry offer supports CSP subscriptions **before** proposing Option B (customer-owned Foundry). If it doesn't, Option B is unavailable for that client until support is added or the client moves off CSP — this is a real subset of clients where the "default to Option B for production" guidance in [docs/04-commercial-models.md](04-commercial-models.md) does not apply.

## 3. Existing volume discounts do not automatically carry over

Consumption-based (CCU / token metering) billing is a different commercial construct from negotiated volume discounts. Reconfirm actual effective pricing with your Anthropic account team before using existing discount assumptions in any Option A vs. Option B cost comparison presented to a client.

## 4. Option B does not mean losing the deal

A multiparty private offer keeps the provider in the transaction as a channel partner, with Microsoft paying the provider directly. When comparing options for internal stakeholders, present Option B's commercial impact as "the provider is compensated differently" rather than "the provider loses the revenue" — the latter is inaccurate and can bias the option choice for the wrong reason.

## 5. APIM SKU determines whether per-client metering actually works

The Anthropic Messages API schema is currently supported only on APIM **v2 tiers**. If the gateway is provisioned on Classic or Consumption tiers, the `llm-emit-token-metric` and related LLM-aware policies will not function correctly against a Claude backend, silently undermining the entire per-client chargeback story. Verify the current tier support matrix before provisioning — this is the single most common way this architecture fails quietly.

## 6. Audit evidence spans two tenants

Because the request path crosses a tenant boundary, complete audit/log evidence for any single call is split between the Customer Tenant (app-level logs, sign-in records) and the Provider Tenant (gateway logs, token metrics, Foundry logs). Agree a joint logging and data-loss-prevention model with each client up front — don't assume either side's logs alone are sufficient for an incident investigation or compliance audit.

## Suggested cadence

Treat items 1–4 as **per-client, per-quarter** checks (they can change independently of any single engagement), and items 5–6 as **per-deployment** checks (verify once per gateway build, and again on any major APIM or Foundry version change).
