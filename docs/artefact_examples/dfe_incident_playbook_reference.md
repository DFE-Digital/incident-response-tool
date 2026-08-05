# DfE Teacher Services — Incident Playbook (reference extract)

Source: https://tech-docs.teacherservices.cloud/operating-a-service/incident-playbook.html

This is a **process playbook**, not a runbook — it describes the
lifecycle every incident goes through, regardless of the technical
detail. Use it as the reference shape for the incident-management
*process artefact* (Step 2) and the *review* artefact (Step 4).

## Lifecycle (five phases, nine numbered steps)

1. **Detect** — automated alerts + support tickets.
2. **Respond** — assemble the trio: **comms lead**, **tech lead**,
   **support lead**. Every subsequent step is annotated with the
   owning role in parentheses (e.g. "(usually comms lead)").
3. **Provide updates during the incident** — running incident thread
   in Teams, timeline maintained in the incident report document.
4. **Upgrading to a security incident** — separate escalation path
   through `#SD Security Support`.
5. **Close and finish reporting** — separate Major Incident reporting
   document if the incident qualifies.
6. **Review to prevent recurrence** — blameless post-mortem, "incident
   and lesson learned review".

## Severity ladder

- **P1** — complete service outage, all users affected.
- **P2** — major degradation, significant portion of users affected.
- **P3** — partial degradation, limited impact.

Note: some services have caps. BigQuery-only incidents cannot exceed
P2. When we frame severity in generated artefacts, honour this pattern:
severity is a function of service + impact, not a raw guess.

## Role vocabulary (use these, not generic titles)

- **Comms lead** — writes Teams updates, drafts external comms,
  coordinates with delivery manager.
- **Tech lead** — owns technical response and coordinates engineers.
- **Support lead** — owns support desk / user-facing tickets.
- **Delivery manager** / **programme delivery manager** — escalation
  above the trio.
- **Deputy director** — for major incidents.
- **Service owner** — for cross-service impact.
- **Lead provider** — external supplier if a vendor is implicated.

## Communication surface

- **Teams thread** (per-incident) — running commentary.
- **`#SD Security Support`** — security escalation channel.
- **SharePoint** — incident report + major incident reporting doc.
- **Upptime** — public status page (not Statuspage, not custom).

## What this reference teaches us

- Every action in a generated process artefact should have an
  **owning role** attached (not a person's name).
- Escalation paths should reference **roles from the vocabulary above**,
  not generic "manager" / "team lead" placeholders.
- Comms actions should default to **Teams + SharePoint**, not Slack.
- Post-incident language should be **blameless** — mirror the
  retrospective prime directive from
  `Incident report template.docx`.
