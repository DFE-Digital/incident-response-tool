---
runbook_id: basket-totals-inconsistent
owner: "@ghbfs-tech"
last_updated: "2026-03-18"
title: "Basket totals shown do not match quote totals"
symptoms:
  - "Schools report the summary basket price differs from the individual quote prices"
  - "Sentry logs BasketTotalMismatch exceptions"
  - "Grafana shows a spike in the `basket.recalculation_failed` metric"
---

## General guidance

Basket totals are cached in Redis for performance and recalculated
whenever a quote is added or removed. If a recalculation fails
mid-flight (e.g. Redis eviction, background job retry), the cached
total can drift from the true sum. This runbook rebuilds the affected
basket totals.

## Pre-requisites

- Access to the `@ghbfs-tech` GitHub team
- `kubectl` configured against the `ghbfs-production` AKS namespace
- The affected school's URN (Unique Reference Number)

## Steps

### 1. Identify the affected baskets

If a single school reported the issue, use their URN:

```
kubectl exec -n ghbfs-production deploy/ghbfs-web -- bundle exec rails baskets:show_totals[<URN>]
```

If the metric spike suggests wider impact, list all baskets with a
mismatch:

```
kubectl exec -n ghbfs-production deploy/ghbfs-web -- bundle exec rails baskets:list_mismatched
```

### 2. Force a recalculation

For a single basket:

```
kubectl exec -n ghbfs-production deploy/ghbfs-web -- bundle exec rails baskets:recalculate[<URN>]
```

For all mismatched baskets:

```
kubectl exec -n ghbfs-production deploy/ghbfs-web -- bundle exec rails baskets:recalculate_all_mismatched
```

The batch task chunks work in batches of 50 to avoid overwhelming
Redis.

### 3. Purge the Redis basket totals cache

```
kubectl exec -n ghbfs-production deploy/ghbfs-web -- bundle exec rails cache:clear[basket_totals]
```

## Verification

Ask the affected school to refresh their basket. The summary total
should match the sum of individual quote totals. Confirm the
`basket.recalculation_failed` metric returns to baseline in Grafana.

## Escalation

If mismatches keep recurring after a full recalculation, escalate to
`@ghbfs-tech` — this suggests a bug in the quote add/remove flow that
needs a code fix, not a runbook remediation.
