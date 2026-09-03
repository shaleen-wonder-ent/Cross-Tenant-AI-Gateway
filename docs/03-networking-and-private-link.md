# 3. Networking and Private Link

## Two supported connectivity paths

| Path | When to use | Notes |
|---|---|---|
| **Cross-tenant Private Link** | Customer requires no public exposure, or has a strict network egress policy | A private endpoint created in the Customer VNet connects to APIM's Private Link service in the Provider Tenant via an **approval workflow** — the provider must accept the connection request. No VPN and no VNet peering are required. |
| **Public endpoint + IP allow-list + TLS** | Faster to stand up, acceptable when the customer's network policy allows scoped public egress | APIM's public gateway endpoint, restricted via IP allow-listing (customer's known egress IPs) and TLS 1.2+. Simpler operationally, weaker isolation than Private Link. |

Both are legitimate — the choice is a customer network-policy question, not an architecture blocker either way.

## VNet peering is not required, and is the wrong tool here

A common first instinct is "don't we need to peer the Customer VNet with the Provider VNet?" No — and it wouldn't be a good fit even if it were an option:

- **VNet peering connects two entire VNets** — it exchanges routes and gives broad L3 reachability between everything in both VNets, requires non-overlapping address spaces, and cross-tenant peering additionally needs an Azure AD B2B/guest trust relationship between the two tenants. That's a lot of shared surface area for "one app needs to reach one gateway."
- **Private Link exposes exactly one resource** (APIM) as a single private IP that gets its own network interface *inside the customer's VNet* — nothing else in either VNet becomes reachable, no routes are exchanged, and there's no CIDR-overlap risk because Private Link NATs the traffic on the provider side.

Practically: the customer creates a **Private Endpoint** in their own subnet pointing at APIM's resource ID (or a shared alias for cross-tenant lookups), the provider **approves** the resulting connection request, and that approval — not network peering — is the actual trust boundary being crossed.

## Why cross-tenant Private Link works

Azure Private Link is designed for exactly this: a **consumer** resource (private endpoint) in one tenant connecting to a **provider** resource (Private Link service) that lives in a different tenant. The provider tenant approves each connection request individually (or via automatic approval rules), which gives natural per-client governance — nothing connects without explicit acceptance.

**NAT is applied by Private Link.** Traffic from the customer's VNet reaching the provider's Private Link service is source-NAT'd, so overlapping RFC1918 address ranges across many customer VNets never collide at the provider side. This matters as soon as more than one client is onboarded onto the same shared gateway — without NAT, address-space collisions would be a real operational risk.

## What lives where

- **Customer VNet**: the ISV Platform's compute (App Service / AKS / VM), an optional private endpoint subnet, an NSG restricting egress to only the gateway's private IP (or its public FQDN, in the public-path option), and a Private DNS zone (`privatelink.azure-api.net`) so the gateway's hostname resolves to the private IP instead of the public one.
- **Provider VNet**: the APIM subnet (v2 tier required — see [docs/05-apim-gateway-configuration.md](05-apim-gateway-configuration.md)), the Private Link service/private endpoint that accepts cross-tenant connection requests, and a **same-tenant** private endpoint from APIM to Microsoft Foundry (with Foundry's public network access disabled).

See [diagrams/03-networking-and-private-link.png](../diagrams/03-networking-and-private-link.png) for the full layout.

## Operational checklist

- [ ] Decide per client: Private Link or public+allow-list (can differ by client, the gateway pattern doesn't care)
- [ ] If Private Link: agree an approval process (manual review vs. auto-approve rules) for new customer connection requests
- [ ] Configure Private DNS zone linking on the customer side so the gateway FQDN resolves privately
- [ ] Disable public network access on the Foundry account once the same-tenant private endpoint to Foundry is live
- [ ] Confirm NSG rules restrict egress from the customer VNet to only the intended gateway endpoint — don't leave broad outbound internet access open "just in case"
