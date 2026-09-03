# Cross-Tenant AI Gateway — First Call Materials

> An application runs **inside an end-customer's Azure tenant**, but the underlying LLM (Anthropic's Claude models via Microsoft Foundry) is consumed from a **different tenant** — the platform provider's own Azure/EA tenant — because that's where the provider's Anthropic contract and API keys live.

## Start here

**[docs/first-call-guide.md](docs/first-call-guide.md)** — the two implementation paths (OAuth2 client-credentials vs. subscription key), what to know about each, the networking approach, and the constraints to plan for.

## Diagrams

| # | File | What it shows |
|---|------|----------------|
| 1 | [diagrams/01-two-options-call-flow.png](diagrams/01-two-options-call-flow.png) | End-to-end call flow with Path 1 (OAuth2) and Path 2 (subscription key) shown as alternative options into the same gateway. |
| 2 | [diagrams/02-network-architecture.png](diagrams/02-network-architecture.png) | Network-layer view: your app → gateway → Foundry → Anthropic, the no-peering constraint, and both connectivity paths. |

Each PNG has an editable `.drawio` source of the same name in the same folder — open with the draw.io VS Code extension, desktop app, or app.diagrams.net.

**[diagrams/network-architecture-live.html](diagrams/network-architecture-live.html)** — an interactive, animated version of the network diagram. Open it directly in any browser (no server needed) and hit **Play flow** to watch the call originate at the end user, cross the tenant boundary, and traverse every component through to Anthropic and back. Toggle Path 1/Path 2 and Private Link/Public endpoint live.
