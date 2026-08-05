---
runbook_id: redis-connection-timeout
owner: "@ghbfs-tech"
last_updated: "2026-01-20"
title: "Redis connection timeouts across the app"
symptoms:
  - "Multiple pages returning 500 errors with Redis::TimeoutError in Sentry"
  - "Sidekiq queue depth spiking across all queues"
  - "Grafana `redis.connection_pool_exhausted` metric > 0"
---

## General guidance

Redis backs our Sidekiq queues, session store, and Rack::Attack rate
limiter. A connection pool exhaustion can happen when a long-running
job holds a connection and other workers back up behind it. This
runbook identifies the blocking client and restarts the pool.

## Pre-requisites

- Access to the `@ghbfs-tech` GitHub team
- Cloud Foundry CLI logged in to production
- Redis CLI access via jump host (see `@ghbfs-tech` runbook wiki)

## Steps

### 1. Identify the blocking client

Connect to Redis and list slow clients:

```
redis-cli -h redis.ghbfs.internal
CLIENT LIST
```

Look for entries with high `age` and `idle` — these are stuck
connections.

### 2. Check for long-running commands

```
SLOWLOG GET 10
```

Note any command taking > 500ms. Common culprits: KEYS, unbounded
LRANGE, blocking pop operations.

### 3. Kill the blocking client

Take the `id` from the CLIENT LIST output and:

```
CLIENT KILL ID <id>
```

Do NOT run `FLUSHALL` or `FLUSHDB` — this will destroy queued jobs.

### 4. Restart the affected worker

Once the blocking client is killed, restart the Sidekiq worker to
force it to re-establish clean connections:

```
cf restart ghbfs-worker
```

## Verification

Watch the `redis.connection_pool_exhausted` metric in Grafana — it
should return to 0 within 2 minutes. Sidekiq queue depth should start
draining.

## Escalation

If connection exhaustion recurs after a restart, escalate to
`@ghbfs-tech` — this suggests a code-level bug (e.g. connections not
being returned to the pool) that needs investigation, not a runbook
remediation.
