---
runbook_id: framework-search-empty-results
owner: "@ghbfs-tech"
last_updated: "2026-05-22"
title: "Framework search returning empty results"
symptoms:
  - "Schools report the framework search returns 'No frameworks found'"
  - "Search works for some queries but not others that used to work"
  - "OpenSearch index count is significantly lower than expected"
---

## General guidance

Framework search is backed by an OpenSearch index rebuilt nightly from
the `frameworks` table. If a rebuild fails partway through the index
can end up empty or partial, producing false negatives for schools
searching for real frameworks.

## Pre-requisites

- Access to the `@ghbfs-tech` GitHub team
- Cloud Foundry CLI logged in to production
- OpenSearch admin credentials (from the shared 1Password vault)

## Steps

### 1. Check current index state

```
curl -u "$OS_ADMIN" https://opensearch.ghbfs.internal/frameworks/_count
```

Compare against the row count in the database:

```
cf run-task ghbfs-web "rails runner 'puts Framework.published.count'"
```

If OpenSearch count is materially lower than the DB count, the index
is stale.

### 2. Kick off a manual reindex

```
cf run-task ghbfs-web "rails frameworks:reindex"
```

This runs in the background. Expected duration: 3–8 minutes depending
on framework volume.

### 3. Watch progress

Tail the worker logs:

```
cf logs ghbfs-web --recent | grep -i reindex
```

### 4. Purge the search results cache

Once reindex completes:

```
cf run-task ghbfs-web "rails cache:clear[framework_search]"
```

## Verification

Search for a known framework (e.g. "RM6238" or "Software Design and
Implementation") on `https://ghbfs.education.gov.uk`. Confirm results
appear within 1 second.

## Escalation

If the reindex task itself fails, escalate to `@ghbfs-tech`. If schools
are reporting missing frameworks after a successful reindex, involve
the `@ghbfs-service` support lead — this may indicate stale data in
the frameworks table itself, not the index.
