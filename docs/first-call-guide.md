# First Call: Two Implementation Paths

You asked for a way to run Anthropic Claude models through Microsoft Foundry, where your application runs in your own tenant, but the model access comes from the provider's tenant. Here are the two ways to authenticate that connection, what to know about each, the networking approach, and the constraints to plan for.

## The shape (same for both paths)

```
Your App (Your Tenant)  --calls-->  Gateway (Provider Tenant)  --calls-->  Microsoft Foundry  --calls-->  Anthropic (Claude)
```

Only the first hop — how your app authenticates to the gateway — changes between the two paths below. Everything after the gateway is identical either way, and is entirely on the provider's side.

## Path 1 — OAuth2 client-credentials

Your app requests a short-lived access token from the provider's identity system (app-only, no end-user involved) and presents it to the gateway.

- **Setup:** one-time app registration on the provider side, then a one-time consent step for your engagement
- **Rotation/revocation:** standard OAuth2 — your credential can be rotated or revoked independently, without affecting anyone else on the same gateway
- **Audit:** strong — every call is tied to a specific, provable client identity
- **Best for:** production, or if you expect to scale usage over time

## Path 2 — Subscription key

Your app sends a static key as a request header. No token exchange, no app registration.

- **Setup:** fastest — a key is issued, your app adds one header
- **Rotation/revocation:** manual — regenerating the key breaks every caller currently using it
- **Audit:** weaker — proves "a valid key was used," not a specific caller
- **Best for:** a fast pilot or proof of concept

## Which to pick

| | Path 1: OAuth2 | Path 2: Subscription key |
|---|---|---|
| Setup effort | Higher (one-time) | Lowest |
| Rotation | Standard, per-client | Manual, shared |
| Audit trail | Strong | Weaker |
| Best fit | Production | Pilot |

You can start on Path 2 for a pilot and move to Path 1 later — nothing past the gateway changes.

## Networking

**Noted constraint: no VNet peering, under any circumstances.** That's not a problem — peering isn't the right tool for this connection anyway. Two options, both compatible with that constraint:

1. **Private Link** — a private endpoint in your VNet connects privately to the gateway over Microsoft's backbone. No VPN, no peering, no shared routing — just one private IP in your own subnet. Requires a one-time connection approval from the provider.
2. **Public endpoint + IP allow-list + TLS** — simpler, no private networking at all. Your egress IPs are allow-listed on the gateway.

Either way, the gateway's own connection to Foundry stays entirely inside the provider's tenant and isn't part of this decision.

Detailed setup and request flows:

- **[Private Link networking guide](private-link-networking.md)** — tenant ownership, private endpoint approval, private DNS, Entra/JWT validation, and the APIM managed-identity hop to Foundry.
- **[Public endpoint networking guide](public-endpoint-networking.md)** — stable customer egress, IP allow-listing, TLS, Entra/JWT validation, and the same managed-identity hop to Foundry.

For the call itself, open [diagrams/network-architecture-live.html](../diagrams/network-architecture-live.html) in a browser and hit **Play flow** — it animates the call originating at the end user, crossing the boundary, and traversing every component through to Anthropic and back, with Path 1/2 and Private Link/Public toggles.

## Constraints to plan for

- **Region and latency:** the provider's tenant is a billing/identity boundary, not a fixed region — the gateway and Foundry can be deployed in a region close to you, subject to where the Claude model is actually available. Confirm the supported region list before committing to a location.
- **Private Link approval is a manual step** the first time — plan for a short lead time on the first connection request.
- **Public-path IP allow-list needs upkeep** if your egress IPs change — a static/reserved egress IP avoids repeated updates.
- **Shared capacity:** if the gateway also serves other clients, usage is quota-isolated per client, but plan headroom so one client's burst doesn't affect others.
- **Cross-tenant logging:** agree up front on a shared correlation ID so a slow or failed call can be traced end-to-end across both sides.

