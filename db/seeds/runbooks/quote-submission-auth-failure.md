---
runbook_id: quote-submission-auth-failure
owner: "@ghbfs-tech"
last_updated: "2026-07-04"
title: "Quote submission failing with auth error"
symptoms:
  - "Suppliers see 'Session expired, please sign in again' when submitting a quote"
  - "Error rate on POST /quotes spikes with 401 responses"
  - "Sentry shows JWT decode errors from the quote submission flow"
---

## General guidance

Quote submissions are authenticated with a short-lived JWT issued by
the DfE Sign-in identity provider. If the JWT signing keys have
rotated and our JWKS cache is stale, all quote submissions will fail
with 401 until the cache is refreshed.

## Pre-requisites

- Access to the `@ghbfs-tech` GitHub team
- Cloud Foundry CLI logged in to production
- Awareness of the DfE Sign-in key rotation schedule (published on
  the DfE Sign-in status page)

## Steps

### 1. Confirm JWKS cache is stale

```
cf run-task ghbfs-web "rails dfe_signin:show_jwks_cache"
```

Compare the `kid` in our cache against the current JWKS from DfE
Sign-in:

```
curl https://dfe-signin.education.gov.uk/.well-known/jwks.json | jq '.keys[].kid'
```

If the `kid` values differ, our cache is stale.

### 2. Clear the JWKS cache

```
cf run-task ghbfs-web "rails dfe_signin:clear_jwks_cache"
```

### 3. Warm the cache with a fresh fetch

```
cf run-task ghbfs-web "rails dfe_signin:refresh_jwks"
```

## Verification

Ask an affected supplier to retry their quote submission. Confirm the
401 rate on `POST /quotes` drops to baseline within 5 minutes on the
Grafana `ghbfs-api` dashboard.

## Escalation

If the JWKS refresh completes but 401s continue, escalate to
`@dfe-signin` — the identity provider itself may be issuing tokens
signed with a key that is not in the JWKS. Do not increase the JWT
grace period without approval.
