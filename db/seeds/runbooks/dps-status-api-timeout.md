---
runbook_id: dps-status-api-timeout
owner: "@ghbfs-tech"
last_updated: "2026-06-15"
title: "DPS status API timing out"
symptoms:
  - "Users see a spinner on the DPS status page that never resolves"
  - "504 Gateway Timeout when hitting /api/dps/status"
  - "Grafana alert on dps-status-api P95 latency > 30s"
---

## General guidance

The DPS (Dynamic Purchasing System) status API pulls live data from
the CCS supplier database via a scheduled sync job. When the sync
backs up, the API times out because it cannot fulfil requests within
the 30-second window. This runbook covers restarting the sync job and
clearing the stuck queue.

## Pre-requisites

- Access to the `@ghbfs-tech` GitHub team
- Cloud Foundry CLI installed and logged in to production
- Read access to the Grafana `ghbfs-production` folder

## Steps

### 1. Confirm the sync job is stuck

Run:

```
cf ssh dps-sync-worker -c "ps aux | grep sync"
```

Verify the sync process has been running > 10 minutes with no
progress. Cross-check the last-successful-sync timestamp in
Grafana → `dps-sync-worker` dashboard.

### 2. Kill the current sync process

```
cf ssh dps-sync-worker -c "pkill -f sync"
```

Wait 30 seconds for the process to fully terminate.

### 3. Clear the pending queue

```
cf run-task dps-sync-worker "rails dps:clear_stuck_jobs"
```

### 4. Restart the sync

```
cf restart dps-sync-worker
```

## Verification

Hit `https://ghbfs.education.gov.uk/api/dps/status`. Should return
`200 OK` with a JSON payload within 5 seconds. Grafana P95 latency
should drop below 5 s within 2 minutes.

## Escalation

If steps do not resolve within 10 minutes, escalate to `@ghbfs-tech`
and consider raising the incident to P2 if user impact continues.
