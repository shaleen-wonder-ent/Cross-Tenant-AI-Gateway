# 2. Identity and the Trust Boundary

## The narrow, defensible claim

It is tempting to summarize this architecture as "avoid Entra ID, use keys instead." That overstates it and isn't quite right. The precise claim is:

> **Don't try to make Entra ID / managed identity cross the tenant boundary at the Foundry hop. Terminate identity at the gateway instead — key/OAuth2 at the front door, managed identity at the back door.**

This matters because a **multi-tenant Entra ID app registration** is a perfectly legitimate part of the design — it just needs to be used at the right hop.

## Two separate identity domains — keep them separate

| Domain | Owned by | Used for |
|---|---|---|
| **Customer Entra ID** | Customer Tenant | App-level authentication/authorization for the ISV Platform (who may sign in and use the app). Conditional Access, MFA, and lifecycle are entirely the customer's to manage. |
| **Provider Entra ID** | Provider Tenant | The model-call trust boundary. Issues the credential the ISV Platform presents to the gateway, and backs the gateway's own managed identity used to reach Foundry. |

A user who is a provider employee but signs in with a customer-issued Entra ID authenticates only within the **Customer Entra ID** domain. That identity is never used to authorize the model call — it's not authoritative for anything inside the Provider Tenant.

## Front door: OAuth2 client-credentials (recommended) or subscription key

Two viable options for the ISV Platform → APIM hop:

| Option | How it works | Trade-off |
|---|---|---|
| **APIM subscription key** | Static shared secret issued per client product | Simple to issue, but no built-in rotation story and weaker audit trail |
| **OAuth2 client-credentials** (recommended) | A multi-tenant Entra ID app registered **once** in the Provider Tenant; each new client onboarding is an **admin-consent step**, not a rebuild. APIM validates the incoming JWT with `validate-jwt`. | Rotatable, revocable, better audit trail; aligns with modern agent-identity direction (e.g., Entra Agent ID) |

Either way, this hop has **no tenant restriction** — it's the same trust shape as calling any external SaaS API with a credential. The Customer Tenant's app just needs network reachability and a valid credential; it does not need to be trusted by the Provider Tenant's Entra ID as a first-class principal.

## Back door: managed identity (same tenant only)

APIM uses the `authentication-managed-identity` policy to obtain an Entra token scoped to the Foundry/Cognitive Services resource. This works cleanly because **APIM and Foundry live in the same tenant (the Provider Tenant)** — this is exactly the case managed identity is designed for. No keys need to be stored for this hop at all.

## Attribution without authentication

The customer's Entra ID (or employee identifier) should still be visible for audit and chargeback — just not as a credential. Pass it as a claim/header (e.g., `x-user-id`) from the ISV Platform to the gateway:

- Used as a `dimension` on the `llm-emit-token-metric` policy for per-user attribution in Azure Monitor.
- Never evaluated by any policy that grants access — it carries no authorization weight.

This is the detail that makes both true at once: managed identity genuinely doesn't work cross-tenant (so don't rely on it at the Foundry hop), and a multi-tenant app registration is not "fragile per client" (so use it, just at the gateway hop, terminating there).

See [diagrams/04-identity-and-token-sequence.png](../diagrams/04-identity-and-token-sequence.png) for the full 14-step sequence, and [docs/05-apim-gateway-configuration.md](05-apim-gateway-configuration.md) for the policy XML that implements this.
