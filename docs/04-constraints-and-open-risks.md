# 4. Constraints and Open Risks

This is the list of things to raise proactively in the **first customer discussion**, before engineering starts. Most of these are network/operational realities of a cross-tenant call path, not architecture flaws — the architecture works either way, but each one shapes engineering effort, the network design conversation, and what to set expectations on up front.

## 1. Cross-region latency and connectivity — the headline challenge to raise on the call

The scenario that triggers this: the customer's tenant/application is in one geography (e.g., the US), while the provider's own tenant historically deploys resources in another (e.g., India). Naively, that reads as "every call now crosses continents twice" — but that's a misconception worth correcting on the call itself.

**The key clarifying point: a tenant is an identity/billing boundary, not a deployment region.** The provider's Azure tenant can provision the APIM gateway and the Foundry/Claude deployment in *any* Azure region it has access to — including a region physically close to the customer — while still billing and governing everything under the provider's own tenant. "Provider Tenant" does not mean "resources physically in India."

That said, real constraints and risks remain, and are worth calling out explicitly:

- **Model/region availability may not match the customer's ideal region.** Claude-on-Foundry deployments are only available in specific regions/data zones (Global Standard / US Data Zone, etc.) — confirm the current supported list before promising a specific low-latency region. This can create tension between "closest region for latency" and "the only region the model is actually available in."
- **Every hop adds round-trip time, and hops compound.** Customer → APIM (cross-tenant, cross-region if not co-located) → Foundry (same-tenant, should be co-located with APIM) → Anthropic (wherever Anthropic's backend for that deployment lives). Even with APIM and Foundry co-located near the customer, the Anthropic inference hop itself is not always the same region.
- **Private Link vs. public endpoint have different latency/reliability profiles.** Private Link rides the Microsoft backbone (generally more consistent latency than public internet transit), but adds the private-endpoint/DNS resolution hop. Public endpoint + allow-list is simpler but subject to public internet routing variability.
- **Connection overhead compounds per-request if not managed.** TLS handshake and connection setup cost is significant on a cross-region path if the ISV Platform opens a new connection per call — connection pooling/keep-alive/HTTP2 on the client side matters more here than in a same-region deployment.
- **Streaming can offset perceived latency even when total latency is higher.** If Anthropic's response is streamed token-by-token, time-to-first-token can stay low even if total completion time is dominated by network RTT — worth demonstrating on the call rather than just quoting a total-latency number.

**Mitigations to bring to the call:**

- Provision APIM and the Foundry deployment in an Azure region close to the customer, under the provider's own tenant — subject to model/region availability above.
- Prefer Private Link over the public path where the customer's policy allows it, for more consistent backbone routing.
- Recommend connection reuse (keep-alive/HTTP2/pooling) in the ISV Platform's HTTP client.
- Enable semantic caching at the gateway for repeated/similar prompts, to avoid a round trip entirely on cache hits.
- Set expectations with a measured baseline: benchmark actual round-trip latency between the customer's region and candidate provider regions *before* committing to a region choice, rather than assuming.

## 2. Operational overhead of the cross-tenant network path

- **Private Link approval is a manual step per client (unless automated).** Every new customer's private-endpoint connection request needs the provider to approve it — agree an SLA/process (or auto-approval rules for known subscription IDs) so this doesn't become an onboarding bottleneck.
- **DNS and allow-list maintenance on the public path.** If Private Link isn't used, the IP allow-list on the provider side needs to track the customer's egress IPs — recommend the customer front their egress with a static/reserved IP (e.g., NAT Gateway) so the allow-list doesn't need constant updates.
- **No peering means no shared routing to lean on for troubleshooting.** Because there's no VNet peering (by the customer's own constraint), standard "traceroute across the peering" diagnostics don't apply — plan for correlation-ID-based, application-layer tracing across both tenants instead (see below).

## 3. Shared capacity contention across clients

If multiple customers share the same gateway and the same underlying Anthropic capacity, one client's burst traffic can affect another's latency/throughput even though quota policies cap tokens-per-minute per client. Size shared capacity with headroom, and monitor aggregate utilization, not just per-client quota compliance.

## 4. Audit evidence and observability span two tenants

Because the request path crosses a tenant boundary, complete audit/log evidence for any single call is split between the Customer Tenant (app-level logs, sign-in records) and the Provider Tenant (gateway logs, token metrics, Foundry logs). Two follow-ons worth raising on the call:

- Agree a joint logging and data-loss-prevention model up front — don't assume either side's logs alone are sufficient for an incident investigation or compliance audit.
- Pass a correlation/request ID end-to-end (customer app → gateway → Foundry) and have both sides log it, so a slow or failed call can be traced across the boundary without needing shared network-level diagnostics.

## 5. Data residency is a product constraint, not just a legal one

A data-processing agreement can cover the legal/contractual side of customer data leaving the customer's tenant, but it cannot manufacture a deployment region that doesn't exist. If a client requires in-country data residency and the current Claude-on-Foundry offering doesn't support a country-local deployment, no amount of contractual cover changes that — the deployment simply cannot meet the requirement as architected, and it also constrains the latency mitigations in item 1. Confirm the current supported region/data-zone list before any client conversation about residency or latency.

## 6. Resiliency — a single-region gateway is a single point of failure

If the provider's chosen APIM/Foundry region has an outage, every customer routed through it is affected. For customers with strict availability requirements, raise multi-region gateway deployment (active-active or active-passive with failover routing) as a follow-on design conversation — not necessarily needed for a first pilot, but worth flagging so it isn't a surprise later.

## Suggested cadence

Treat item 5 (data residency) as a **per-client, per-quarter** check — it can change independently of any single engagement. Treat items 1–4 and 6 as **per-deployment** design decisions to work through explicitly with each customer during the network-design part of the first call, since the right answer (region choice, Private Link vs. public, capacity headroom, resiliency tier) will differ per customer.

> Commercial-model-specific constraints (CSP support, existing volume discounts, Option A/B billing mechanics) live with the rest of the build-out material in [phase-2-implementation/docs/04-commercial-models.md](../phase-2-implementation/docs/04-commercial-models.md) — those are a later-stage conversation, not part of the first technical discussion.
