# Phase 2 — Implementation and Build-Out

This folder contains the material for **after** the customer has picked a direction in the first-call discussion (see [../docs/00-first-call-discussion-guide.md](../docs/00-first-call-discussion-guide.md)). It covers the commercial model, concrete APIM policy configuration, and the step-by-step build runbook.

## Contents

| File | What it covers |
|---|---|
| [docs/04-commercial-models.md](docs/04-commercial-models.md) | Option A (provider-owned Foundry) vs. Option B (customer-owned Foundry) — a separate, commercial-model decision from the Option 1/Option 2 front-door auth choice covered in the first-call guide. Includes CSP support and volume-discount caveats. |
| [docs/05-apim-gateway-configuration.md](docs/05-apim-gateway-configuration.md) | Concrete APIM policy XML, the v2-tier SKU requirement, and setup/testing steps. |
| [docs/06-implementation-runbook.md](docs/06-implementation-runbook.md) | Phase-by-phase build checklist from Foundry provisioning through go-live. |
| [policies/gateway-inbound-policy.xml](policies/gateway-inbound-policy.xml) | Ready-to-adapt APIM inbound/outbound policy implementing both front-door options, managed identity to Foundry, quota isolation, and token metrics. |
| [diagrams/05-commercial-options-comparison.drawio](diagrams/05-commercial-options-comparison.drawio) / [.png](diagrams/05-commercial-options-comparison.png) | Option A vs. Option B side by side. |

> **Don't confuse the two "Option" pairs in this repo:** the first-call guide's **Option 1/Option 2** is about *which credential authenticates the front door* (OAuth2 vs. subscription key) — an engineering decision made early. This folder's **Option A/Option B** is about *who owns the Foundry/Anthropic contract* (provider vs. customer) — a commercial decision made once the engagement scales. Either front-door option works under either commercial model.
