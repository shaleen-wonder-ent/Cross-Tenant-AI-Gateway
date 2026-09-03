# 0. First Customer Discussion Guide — Two Implementation Options

**Use this doc to run the first-level architecture discussion with the customer.** It presents the two viable front-door implementation options, the network design decisions that go with each, and the challenges to raise proactively — before any engineering commitment is made. Deeper technical detail lives in the docs it links to; build-out material (once an option is chosen) lives in [phase-2-implementation/](../phase-2-implementation/).

## The shape both options share

Regardless of which option the customer prefers, the overall shape is fixed (see [docs/01-architecture-overview.md](01-architecture-overview.md) for the full explanation):

```
Customer Tenant (AI Force App)  --calls-->  APIM hosted in Provider Tenant  --calls-->  Foundry (managed identity)  --calls-->  Anthropic
```

The only thing that changes between the two options is **how the ISV Platform authenticates to APIM** — the front-door hop. Everything from APIM onward (managed identity to Foundry, Foundry's internal call to Anthropic) is identical either way.

## Option 1 — OAuth2 client-credentials

The ISV Platform requests an app-only access token from the Provider Tenant's Entra ID (`client_credentials` grant) using a `client_id`/secret issued at onboarding, then presents that token as a Bearer JWT to APIM, which validates it with `validate-jwt`.

- **Engineering effort:** a one-time multi-tenant Entra ID app registration in the Provider Tenant, then an admin-consent step per new client. The ISV Platform needs an OAuth2 token-acquisition call added to its client (most HTTP/identity libraries support `client_credentials` natively).
- **Rotation/revocation:** standard OAuth2 secret/certificate rotation; a single client can be revoked independently by disabling its credential or app registration, without affecting other clients.
- **Audit trail:** strong — JWT claims (issuer, audience, client id) are available to log at the gateway.
- **Alignment:** matches where Microsoft's agent-identity direction is heading (e.g., Entra Agent ID), so it ages better than a shared secret model.

## Option 2 — APIM subscription key

The ISV Platform presents a static subscription key (`Ocp-Apim-Subscription-Key` header) issued per client product in APIM. No Entra ID app registration is required.

- **Engineering effort:** lowest — issue a key, the ISV Platform sends it as a header. No token-acquisition logic needed on the client side.
- **Rotation/revocation:** manual — regenerating a key breaks every caller currently using it; there's no per-caller expiry/rotation story built in.
- **Audit trail:** weaker — a key proves "a valid subscription," not a specific, individually revocable identity the way a JWT's claims do.
- **Alignment:** simplest to stand up for a pilot; less future-proof if going to broader agent-identity governance later.

## Comparison at a glance

| | Option 1: OAuth2 client-credentials | Option 2: APIM subscription key |
|---|---|---|
| Setup effort | Higher (one-time app registration + per-client consent) | Lower (issue a key) |
| Client-side change | Add token-acquisition call | Add a header |
| Rotation | Standard OAuth2 | Manual, shared secret |
| Revocation granularity | Per client, independently | Regenerate breaks all current callers |
| Audit trail | Strong (JWT claims) | Weaker (key presence only) |
| Recommended for | Production, multiple clients, governance-sensitive engagements | Fast pilots, single-client proofs of concept |

Both are fully supported by the same gateway — a client can start on Option 2 for a fast pilot and move to Option 1 later without changing anything past the front door. See [docs/02-identity-and-trust-boundary.md](02-identity-and-trust-boundary.md) for the full mechanics of both, and how identity is deliberately terminated at the gateway either way.

## Network design — the part to align on early

**Hard constraint going in: the customer will not allow VNet peering under any circumstances.** That's not a blocker — Private Link and VNet peering solve different problems, and Private Link is the correct tool here regardless of that constraint. Two options to present:

1. **Cross-tenant Private Link** — a private endpoint in the Customer VNet connects to APIM's Private Link–enabled endpoint in the Provider Tenant via an approval workflow. No VPN, no peering, no route exchange — it's a single private IP/NIC in the customer's own subnet, not a tunnel into the provider's network.
2. **Public endpoint + IP allow-list + TLS** — simpler to stand up, no private networking at all, isolation relies on IP allow-listing and TLS instead of a private path.

Managed identity (APIM → Foundry) is the same in both cases — it's a same-tenant hop on the provider side and isn't part of this discussion with the customer at all.

Full mechanics, including why Private Link ≠ peering, live in [docs/03-networking-and-private-link.md](03-networking-and-private-link.md).

## Challenges to raise proactively on the call

The headline one: **if the customer's tenant/app is in one geography and the provider's tenant historically deploys in another (e.g., customer in the US, provider historically in India), does that create a latency problem — and how would it be solved?**

Short answer to bring to the call: a tenant is an identity/billing boundary, not a deployment region — the provider's tenant can provision APIM and Foundry in a region close to the customer while still billing under the provider's own tenant. But region choice is still constrained by where the model itself is available, and several other operational challenges compound with distance. The full list — latency budget, mitigations, Private Link approval overhead, DNS/allow-list maintenance, shared capacity contention, cross-tenant observability, and resiliency — is in [docs/04-constraints-and-open-risks.md](04-constraints-and-open-risks.md). Walk through that section explicitly; it's written to be presented, not just referenced.

## Suggested agenda for the call

1. Recap the overall architecture shape (2 minutes, use [diagrams/01-solution-architecture-overview.png](../diagrams/01-solution-architecture-overview.png))
2. Present Option 1 vs. Option 2 and get a preference or a "need to think about it" (use [diagrams/06-two-options-call-flow.png](../diagrams/06-two-options-call-flow.png))
3. Confirm the no-peering constraint and walk Private Link vs. public endpoint (use [diagrams/07-network-architecture.png](../diagrams/07-network-architecture.png))
4. Walk through the challenges section and mitigations — set expectations, don't oversell
5. Agree next steps: which option, which connectivity path, and what needs a follow-up session (e.g., a latency benchmark, a security review of Private Link approval process)

## Diagrams for this call

| Diagram | Shows |
|---|---|
| [diagrams/06-two-options-call-flow.png](../diagrams/06-two-options-call-flow.png) | End-to-end call flow with Option 1 and Option 2 shown as alternative front-door paths into the same gateway |
| [diagrams/07-network-architecture.png](../diagrams/07-network-architecture.png) | Network-layer view: Customer → APIM → Foundry → Anthropic, the no-peering constraint, and both connectivity paths |

## Once the customer has picked a direction

Move to [phase-2-implementation/](../phase-2-implementation/) for the commercial model, concrete APIM policy configuration, and the implementation runbook.
