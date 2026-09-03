# 8. Diagrams Index — How to Open, Edit, and Animate

All diagrams are plain `.drawio` XML files (uncompressed, human-diffable) under [diagrams/](../diagrams/).

## Opening the diagrams

Any of the following work:

- **VS Code**: install the "Draw.io Integration" extension, then open any `.drawio` file directly in the editor.
- **Desktop app**: [draw.io desktop](https://github.com/jgraph/drawio-desktop) — File → Open.
- **Browser**: go to [app.diagrams.net](https://app.diagrams.net) → File → Open From → Device, and select the file.

## Diagram-by-diagram guide

### 1. `01-solution-architecture-overview.drawio`
A 5-row × 3-column grid (Identity & Access, Application & Network, AI Platform, Commercial & Billing, Risk & Governance across Customer Tenant / Cross-Tenant Boundary / Provider Tenant). Use this as the first slide in any stakeholder walkthrough — it's the one-page summary of the entire architecture.

### 2. `02-cross-tenant-request-and-token-flow.drawio`
Numbered (1–10) component flow from the end user through the ISV Platform, across the tenant boundary, through the gateway and Foundry, to Anthropic, and back through billing. Use this when someone asks "walk me through exactly what happens on a single call."

### 3. `03-networking-and-private-link.drawio`
Network engineers' view: VNets, subnets, NSGs, DNS, and the cross-tenant Private Endpoint approval workflow, plus the public-endpoint alternative. Use this with the customer's network/security team specifically.

### 4. `04-identity-and-token-sequence.drawio`
A 14-step sequence diagram (lifelines for User, ISV Platform, Key Vault, Gateway, Provider Entra ID, Foundry, Anthropic) showing exactly which credential is used at each hop and where identity terminates. Use this to settle any "wait, whose identity is this?" question definitively.

### 5. `05-commercial-options-comparison.drawio`
Option A vs. Option B, side by side, including the billing/contracting differences and the watch-outs for each. Use this in the commercial/procurement conversation, separate from the technical walkthrough.

### 6. `06-animated-call-flow.drawio`
A simplified 5-node version of diagram 2, with edges styled `flowAnimation=1` — when opened in draw.io (desktop, web, or the VS Code extension), the arrows visibly pulse in the direction of travel, color-coded: blue = outbound request, green = response, orange dotted = asynchronous token-metering emission. This is the "just show me it working" diagram for a live session — no export/video needed, it animates natively when opened.

## Editing conventions used across all diagrams

- **Blue** (`#dae8fc` / `#6c8ebf`) = Customer Tenant resources
- **Green** (`#d5e8d4` / `#82b366`) = Provider Tenant resources
- **Gray** (`#f5f5f5` / `#666666`) = cross-tenant boundary / neutral infrastructure
- **Orange** (`#ffe6cc` / `#d79b00`) = Anthropic-operated / third-party components, or things needing reconfirmation
- **Red** (`#f8cecc` / `#b85450`) = constraints/blockers to validate before production
- **Purple** (`#e1d5e7` / `#9673a6`) = billing/metering/monitoring paths

Keep this palette when extending any diagram so a viewer can tell at a glance which tenant a box belongs to without reading the text.
