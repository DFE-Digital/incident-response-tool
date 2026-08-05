---
runbook_id: deploy-rollback
owner: "@ghbfs-tech"
last_updated: "2026-07-22"
title: "Rollback a bad deploy to production"
symptoms:
  - "Error rate spiked immediately after a deploy went live"
  - "Users report a new feature is broken and was not broken before the deploy"
  - "CI dashboard shows the most recent deploy went out in the last hour"
---

## General guidance

Every production deploy is tagged with the commit SHA. Cloud Foundry
keeps the previous three releases, allowing a fast rollback with
`cf rollback`. This should be the first response to a deploy that
caused a regression — investigate the root cause after service is
restored, not during.

## Pre-requisites

- Access to the `@ghbfs-tech` GitHub team
- Cloud Foundry CLI logged in to production
- Awareness that rollback reverts application code only, not database
  migrations

## Steps

### 1. Confirm the bad deploy is the cause

Check the timing: did the error rate spike within 5 minutes of the
deploy going live? Compare against the release timeline in
CircleCI / GitHub Actions.

### 2. Identify the previous good revision

```
cf revisions ghbfs-web
```

Note the revision number just before the current one.

### 3. Roll back

```
cf rollback ghbfs-web --revision <previous-revision-number>
```

Confirm at the prompt. CF will re-deploy the previous release. Expect
30–60 seconds of rolling replacement.

### 4. Verify database compatibility

If the bad deploy included a migration, check whether the previous
release can run against the current schema. Usually additive
migrations (new columns, new tables) are backwards-compatible.
Destructive migrations (dropped columns) are NOT — do not roll back
past a destructive migration without a schema rollback plan.

## Verification

Watch the error rate in Grafana — should return to baseline within
2 minutes. Ask the reporter to retry the broken flow and confirm it
works.

## Escalation

If a rollback isn't safe because of an incompatible migration,
escalate to `@ghbfs-tech` immediately. Options are: forward-fix
(riskier, faster), or coordinate a schema rollback (safer, slower).
Do NOT run destructive database changes without incident commander
approval.
