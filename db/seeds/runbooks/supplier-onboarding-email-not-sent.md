---
runbook_id: supplier-onboarding-email-not-sent
owner: "@ghbfs-service"
last_updated: "2026-04-30"
title: "Supplier onboarding email not received"
symptoms:
  - "New suppliers report they never received the onboarding email"
  - "Suppliers cannot complete registration because the verification link is required"
  - "GOV.UK Notify shows the email as 'permanent-failure' or 'technical-failure'"
---

## General guidance

Supplier onboarding emails are sent through GOV.UK Notify. A failure
can be caused by an invalid supplier email address, a Notify service
issue, or our template being disabled. This runbook walks through
diagnosing the failure mode and re-sending.

## Pre-requisites

- Access to the `@ghbfs-service` support team
- GOV.UK Notify account with access to the "GHBfS" service
- The supplier's registration reference number

## Steps

### 1. Look up the message in Notify

Sign in to `https://www.notifications.service.gov.uk/`, select the
"GHBfS" service, and search by the supplier's email address in the
"Sent messages" view.

### 2. Read the failure reason

- `permanent-failure` → email address is invalid; contact the
  supplier by phone to correct it, then trigger step 4.
- `technical-failure` → Notify had a delivery issue; check the
  GOV.UK Notify status page. If Notify is healthy, trigger step 4.
- `temporary-failure` → recipient's inbox is temporarily rejecting
  mail. Wait 30 minutes and check again before re-sending.

### 3. Confirm our template is active

```
cf run-task ghbfs-web "rails notify:template_status[supplier_onboarding]"
```

Output should show `active: true`.

### 4. Resend the onboarding email

```
cf run-task ghbfs-web "rails suppliers:resend_onboarding[<reference>]"
```

Replace `<reference>` with the supplier's registration reference.

## Verification

Confirm the supplier receives the email within 5 minutes and can
click through to the verification page.

## Escalation

If Notify is showing a service degradation on their status page, no
further action is possible — communicate the delay to the supplier
and monitor for recovery. If our template is disabled and cannot be
re-enabled, escalate to `@ghbfs-tech`.
