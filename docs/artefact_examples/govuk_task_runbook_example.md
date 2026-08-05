# GOV.UK Publishing Mobile — Remote Config Runbook (reference extract)

Source: https://docs.publishing.service.gov.uk/mobile/backend/remote-config-runbook.html

This is a **task runbook**, not an incident playbook — it tells the
on-caller *exactly what to type* to perform one specific operation
(here, disabling app features). Use this as the reference shape for
the retrieved/drafted runbook artefact (Step 3).

## Shape

1. **General guidance** — one paragraph of context (when to use this,
   what it does, what it doesn't do).
2. **Pre-requisites** — access rights, tooling, team membership
   (e.g. `@gov-uk-production-admin` GitHub team). Explicit *before*
   any procedural step.
3. **Action-phrased section headings** — each heading is a verb
   describing what you're doing, not a noun describing a system.
   Examples from the source:
   - "Switching the app off entirely"
   - "Disabling an individual feature"
   - "Forcing users to update"
4. **Inline commands** — the exact command a reader should type,
   e.g. `npm start validate`, `npm start generate`. Not pseudocode.
5. **Verification step** — how to confirm the change took effect
   (a specific endpoint to hit, a status page to check).
6. **Cache-purge / CDN note** — where relevant, an explicit line about
   Fastly / CDN invalidation for urgent changes.

## Access-control pattern

Access is governed by **GitHub team membership**, not by named people
(`@gov-uk-production-admin`). Generated runbooks should follow this
pattern:

- `owner: @<team-handle>` rather than `owner: Sarah Smith`.
- Anyone on the team can execute the runbook without a change of
  permissions.

## Environment vocabulary

The source uses **production / staging / integration** — not
"prod / dev / QA". Match this in generated runbooks.

## Style tokens that make it read as GOV.UK

- Team names not individual names.
- "Emergency change" and "urgent situations" for out-of-hours actions.
- Cross-references to the wiki ("see Incident management wiki").
- OGL v3.0 + Crown copyright footer.

## What this reference teaches us

For the retrieved/drafted runbook artefact (Step 3), the schema should
be:

- `runbook_id` (URL-safe slug)
- `owner` (team handle, e.g. `@ghbfs-tech`)
- `last_updated` (ISO date)
- `general_guidance` (1 paragraph)
- `pre_requisites[]` (access + tooling, before any step)
- `steps[]` — each step has:
  - `action` (verb-phrased heading)
  - `commands[]` (exact commands or endpoint calls)
  - `verification` (how to confirm)
- `escalation_owner` (team handle, for when steps don't resolve)
- `notes` (optional — cache purge, CDN, emergency-change caveats)

If Claude drafts a runbook (rather than retrieving one), it should
produce output in this exact shape so the drafted stub is
indistinguishable from a real one.
