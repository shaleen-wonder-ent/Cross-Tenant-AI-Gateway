# 5. APIM Gateway Configuration

## SKU requirement — read this first

The `llm-emit-token-metric` policy itself works on all APIM tiers, but the **Anthropic Messages API schema is currently only supported on API Management v2 tiers**. Since Claude on Foundry is accessed through the Messages API, **the gateway must be provisioned on a v2 tier** (e.g., Basic v2 / Standard v2) or per-client token metering and quota enforcement will not work for this backend. Confirm the current supported tier list before provisioning, as APIM SKU/feature support evolves.

Also confirm before deploying:
- The APIM instance is integrated with Application Insights (required for `llm-emit-token-metric` to actually emit data)
- Custom metrics with dimensions are enabled in Application Insights
- Azure Monitor's custom-metrics limits apply: max 5 custom dimensions per policy instance, 100 unique values per dimension, 1,000 active time series per metric namespace per region — size your dimension choices (client, user, model, API) accordingly

## Policy layering (inbound order)

1. **Front-door authentication** — `validate-jwt` (OAuth2 client-credentials, recommended) or subscription-key validation
2. **Resolve caller identity** — map the credential to a client id for quota/metering; capture the customer's user claim separately, for attribution only
3. **Per-client quota isolation** — `llm-token-limit` + `rate-limit-by-key`, both keyed by client id, so one client's spike cannot starve another's share of shared Anthropic capacity
4. **(Optional) Content safety** — `llm-content-safety` before forwarding to the model
5. **Back-door authentication** — `authentication-managed-identity` to reach Foundry, same tenant
6. **Backend selection** — `set-backend-service` pointing at the Foundry Claude deployment
7. **Token metrics (outbound)** — `llm-emit-token-metric`, dimensioned by client/user/model for chargeback

See [policies/gateway-inbound-policy.xml](../policies/gateway-inbound-policy.xml) for a complete, adaptable policy document implementing all of the above.

## Why OAuth2 client-credentials over a subscription key

| | Subscription key | OAuth2 client-credentials |
|---|---|---|
| Setup effort | Lower | One-time multi-tenant app registration, then admin-consent per client |
| Rotation | Manual, shared secret | Standard OAuth2 rotation/expiry |
| Revocation | Regenerate key (all callers using it break) | Revoke consent or disable the specific client's credential |
| Audit trail | Weak (a key is a key) | Strong (JWT claims, issuer, per-client app registration) |
| Aligns with | — | Emerging agent-identity patterns (e.g., Entra Agent ID) |

Recommendation: **OAuth2 client-credentials per client.** The extra setup is a one-time cost; the governance story (the actual value proposition of the gateway) depends on being able to rotate and revoke per client without shared-secret blast radius.

## Backend setup (same-tenant hop to Foundry)

```bash
# Create the backend pointing at the Foundry account's Claude deployment
az apim backend create --service-name <apim> --resource-group <rg> \
  --backend-id foundry-claude-backend --protocol http \
  --url "https://<foundry-account>.cognitiveservices.azure.com"

# Grant the APIM managed identity access to the Foundry resource
az role assignment create --assignee <apim-principal-id> \
  --role "Cognitive Services User" --scope <foundry-resource-id>
```

## Testing

```bash
GATEWAY_URL=$(az apim show --name <apim> --resource-group <rg> --query "gatewayUrl" -o tsv)

curl -X POST "${GATEWAY_URL}/anthropic/v1/messages" \
  -H "Authorization: Bearer <client-credentials-token>" \
  -H "x-client-id: <client-id>" \
  -H "x-user-id: <customer-entra-object-id>" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-3-5-sonnet","max_tokens":256,"messages":[{"role":"user","content":"Hello"}]}'
```

Confirm the response includes `x-tokens-consumed` / `x-tokens-remaining` headers, and that a corresponding `Total Tokens` custom metric appears in Application Insights dimensioned by `ClientId`.
