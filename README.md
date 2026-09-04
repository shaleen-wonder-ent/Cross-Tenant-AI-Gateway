# Cross-Tenant AI Gateway — First Call Materials

> An application runs **inside an end-customer's Azure tenant**, but the underlying LLM (Anthropic's Claude models via Microsoft Foundry) is consumed from a **different tenant** — the platform provider's own Azure/EA tenant — because that's where the provider's Anthropic contract and API keys live.

## Start here

**[docs/first-call-guide.md](docs/first-call-guide.md)** — the two implementation paths (OAuth2 client-credentials vs. subscription key), what to know about each, the networking approach, and the constraints to plan for.

## Detailed networking guides

| Option | Guide | What it covers |
|---|---|---|
| Private Link | [docs/private-link-networking.md](docs/private-link-networking.md) | Cross-tenant private endpoint approval, private DNS, Entra/JWT validation at APIM, and managed identity from APIM to Foundry. |
| Public endpoint | [docs/public-endpoint-networking.md](docs/public-endpoint-networking.md) | Stable customer egress, IP allow-listing, TLS, Entra/JWT validation at APIM, and managed identity from APIM to Foundry. |

## Diagrams

### 1. Two front-door options — call flow

End-to-end call flow with Path 1 (OAuth2) and Path 2 (subscription key) shown as alternative options into the same gateway.

<img src="diagrams/01-two-options-call-flow.svg" alt="Two front-door options — call flow" width="100%">

### 2. Network architecture

Network-layer view: your app → gateway → Foundry → Anthropic, the no-peering constraint, and both connectivity paths.

<img src="diagrams/02-network-architecture.svg" alt="Network architecture" width="100%">

Each SVG has an editable `.drawio` source of the same name in the same folder — open with the draw.io VS Code extension, desktop app, or app.diagrams.net.

**[diagrams/network-architecture-live.html](diagrams/network-architecture-live.html)** — an interactive, animated version of the network diagram. Open it directly in any browser (no server needed) and hit **Play flow** to watch the call originate at the end user, cross the tenant boundary, and traverse every component through to Anthropic and back. Toggle Path 1/Path 2 and Private Link/Public endpoint live.
