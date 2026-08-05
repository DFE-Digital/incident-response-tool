---
runbook_id: user-locked-out-2fa
owner: "@ghbfs-service"
last_updated: "2026-06-01"
title: "School user locked out due to lost 2FA device"
symptoms:
  - "User reports they cannot sign in because they've lost their phone"
  - "User cannot receive the SMS or authenticator code"
  - "Multiple failed 2FA attempts have triggered a 24-hour lockout"
---

## General guidance

Users authenticate through DfE Sign-in, which supports SMS and
authenticator-app 2FA. When a user loses their device, we cannot
reset 2FA on their behalf directly — this is done by the DfE Sign-in
support team, but we can validate the request and hand off cleanly.

## Pre-requisites

- Access to the `@ghbfs-service` support team
- The user's DfE Sign-in registered email address
- Confirmation the request came through an official school channel
  (not a personal email)

## Steps

### 1. Verify the user's identity through official channels

Confirm the request is from a real school administrator by:

- Checking the user's email domain matches a registered school domain
  in our database, or
- Ringing back on the school's published phone number (do not use a
  number provided in the reset request itself)

### 2. Confirm the account exists and is not suspended

```
kubectl exec -n ghbfs-production deploy/ghbfs-web -- bundle exec rails users:show[<email>]
```

Note the user's DfE Sign-in identifier for the handoff.

### 3. Hand off to DfE Sign-in support

Raise a ticket at `https://support.signin.education.gov.uk` with:

- User's email
- DfE Sign-in identifier from step 2
- Confirmation that identity has been verified through step 1

DfE Sign-in support responds within 4 working hours during business
hours.

### 4. Notify the user

Send an acknowledgement email using the "2fa-reset-in-progress"
Notify template:

```
kubectl exec -n ghbfs-production deploy/ghbfs-web -- bundle exec rails users:send_2fa_reset_ack[<email>]
```

## Verification

Ask the user to attempt sign-in once DfE Sign-in confirms the reset.
Confirm they land on the GHBfS dashboard.

## Escalation

If DfE Sign-in support is unavailable (e.g. bank holiday) and the user
has an urgent need, escalate to `@ghbfs-service` support lead who can
authorise a temporary account bypass through the emergency channel.
Never bypass 2FA outside this documented path.
