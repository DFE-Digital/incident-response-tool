# Plan — Incident Response Tool (2-day build)

Sequenced feature plan for the grad-project build. Each step names what
gets built, the input, the output, and the review moment so we can nod
"yes" or "change that" before moving on.

Reference: `team-idea-blended.md` (scope), `docs/ai-log.md` (session log).

## Product in one sentence

The user describes an incident in free text; the service returns
structured artefacts — an incident-management process to follow, a
grounded runbook (retrieved or drafted) with citations, and — once the
incident is closed — a post-incident review draft. All rendered in
GOV.UK design system components on top of the boilerplate Rails app.

## What the repo gives us for free

- Rails 6.0 + Webpacker
- GOV.UK Frontend + `govuk_design_system_formbuilder` + `govuk-components`
- PostgreSQL + RSpec + Docker + docker-compose

Everything below assumes we're extending this stack, not replacing it.

## Tooling defaults for generated artefacts

DfE is **no longer on CloudFoundry / GOV.UK PaaS** (decommissioned Dec
2023). Runbook commands, drafted steps, and infra examples should
default to **Azure Kubernetes Service (AKS)** patterns:

- `kubectl exec -n <ns> deploy/<name> -- <cmd>` (not `cf ssh`)
- `kubectl logs -n <ns> deploy/<name> --tail=N` (not `cf logs`)
- `kubectl rollout restart deployment/<name>` (not `cf restart`)
- `kubectl rollout undo deployment/<name> --to-revision=N` (not `cf rollback`)
- Rake tasks via `kubectl exec deploy/<name> -- bundle exec rails <task>`
- Azure CLI (`az`) for cloud-level ops

Applies to both the seed runbook corpus and anything Claude drafts.

---

## Step 0 — Foundations (before feature work)

**Goal:** boot the boilerplate, wire Claude, prove one round-trip.

- Get the Rails app running (`bundle install`, `yarn`, `bin/rails db:setup`,
  `bundle exec rails server`) — confirm the boilerplate homepage renders
  with GOV.UK styling.
- Add `anthropic` Ruby SDK (or `httparty`-based client) + `dotenv`
  handling for `ANTHROPIC_API_KEY`.
- Health-check endpoint that calls Claude once and returns "ok" — proves
  the API key + network path.

**Review moment:** app boots, GOV.UK styles load, Claude round-trip works.

---

## Step 1 — Incident intake (chat UI)

**Goal:** the user can describe an incident in free text and see a
response.

- Route `/incidents/new` — a GOV.UK-styled form: title + free-text
  textarea + service dropdown ("Get Help Buying for Schools" is the seed
  option, but the field is open).
- `Incident` model persisted in Postgres (`title`, `description`,
  `service`, `status: open|resolved`, timestamps).
- On submit → creates the incident and redirects to `/incidents/:id`.
- The show page renders the incident and (initially) a single "Generate
  next steps" button.

**Input:** user's free-text incident description.
**Output:** a persisted `Incident` record and a show page ready for
artefacts.

**Review moment:** form + persistence look right; GOV.UK styling is
consistent.

---

## Step 2 — Artefact: incident-management process

**Goal:** turn the description into a structured "what to do right now"
checklist.

- "Generate next steps" triggers a Claude call.
- System prompt frames Claude as an incident-response coach for a UK gov
  digital service. Structured output schema:
  - `severity_guess` (P1–P4 with reasoning)
  - `immediate_actions[]` (triage, containment)
  - `communication_actions[]` (who to notify, when — service owner,
    users, comms lead)
  - `escalation_path[]` (named roles, not people)
- Rendered as a GOV.UK task-list on the incident page.
- Persisted as a `ProcessArtefact` belonging to the incident.

**Input:** incident description.
**Output:** a persisted process artefact rendered as a GOV.UK task list.

**Review moment:** does the process feel like something an on-caller
would actually follow at 2am?

---

## Step 3 — Artefact: runbook (retrieved or drafted)

**Goal:** ground the response in the team's runbooks, or refuse cleanly.

- Author a synthetic runbook corpus in `db/seeds/runbooks/*.md`
  (~10–15 files, realistic GHBfS-shaped: DPS timeout, framework search
  empty, quote submission auth failure, etc.). Each runbook has an ID,
  owner, last-updated date, and clear step sections.
- Corpus loaded into Claude's system prompt with `cache_control` — no
  vector DB (see `team-idea-blended.md` for the architectural rationale).
- Claude call with structured output:
  - `match`: `retrieved` | `drafted` | `refused`
  - `runbook_id` (nullable) + `cited_section` (nullable)
  - `steps[]` (the runbook steps to follow now)
  - `owner_to_escalate_to` (always present)
- If `refused`, the page shows a clear GOV.UK notification banner:
  *"no runbook covers this — escalate to \<owner\>"*.
- Persisted as a `RunbookArtefact`.

**Input:** incident description + cached runbook corpus.
**Output:** a runbook artefact — either a retrieved runbook with
citation, or a drafted stub, or an honest refusal.

**Review moment:** citation contract holds, refusal path fires on the
seeded "no-match" cases.

---

## Step 4 — Artefact: post-incident review

**Goal:** once the incident is resolved, produce a review draft in the
exact shape of DfE's real incident-report template — so Serena's team
can paste it straight into their working doc.

Reference: `docs/artefact_examples/Incident report template.docx`.

### Input form (on "Mark resolved")

The "Mark resolved" button opens a form that captures what we don't
already have on the `Incident` record:

- End date & time (defaults to now)
- Technical lead, Comms lead, Support lead (three text fields)
- Timeline events — repeating rows of `time` + `event`
- Free-text resolution notes

The rest of the header (status, start/detection times,
application/process, priority) comes from the existing `Incident` +
`ProcessArtefact` records.

### Claude call — review schema

The schema mirrors the template's "Incident Review" section:

- `user_impact` (1–2 sentences, generated from the incident description
  in the voice of the template's example: *"Users will be unable to
  … and … will not be able to …"*)
- `root_cause` (1–2 sentences)
- `alerted_quickly` (were we alerted quickly? — 1 paragraph)
- `diagnosed_and_fixed_quickly` (were we able to diagnose and fix the
  immediate issue quickly? — 1 paragraph)
- `how_we_solved_it` (1 paragraph)
- `process_and_comms` (was the process followed well, were comms
  effective? — 1 paragraph)
- `prevent_recurrence[]` (bulleted actions — what could we do to prevent
  this from happening again?)
- `improve_response[]` (bulleted actions — what could we do to improve
  our response?)
- `improve_process_comms[]` (bulleted actions — what could we do to
  improve comms/process?)
- `runbook_diff` — Markdown patch against the retrieved runbook, or a
  new runbook stub if none was matched

The review artefact is rendered on the show page opening with the
template's retrospective prime directive quote verbatim, then the
header table, timeline, and the review sections above as a GOV.UK
summary list. Persisted as a `ReviewArtefact`.

**Input:** incident + process artefact + leads + timeline + resolution
notes.
**Output:** a review artefact laid out in the exact shape of the DfE
template, ready to be exported as Markdown.

**Review moment:** review reads like something Serena would actually
paste into the team's incident doc, not like generic LLM boilerplate.

---

## Step 5 — Teams integration (thread + auto-populated artefacts)

**Goal:** every incident opens its own conversation in a designated
Teams channel and is kept up to date automatically as artefacts are
generated. This is the primary comms surface for the on-call team —
matches the DfE Teacher Services playbook (see
`docs/artefact_examples/dfe_incident_playbook_reference.md`) where the
Teams thread is where the incident actually lives.

Previously S2 in stretch; promoted to a main goal because it's the
feature that makes the tool actually reduce toil rather than adding
another tab to check.

- **On incident creation (Step 1 hook):** post an "Incident opened"
  message to the configured Teams channel with title, affected service,
  reporter, description, and a link back to the incident show page.
  Persist the returned message identifier as `Incident#teams_thread_id`.
- **On process artefact generation (Step 2 hook):** reply into the
  incident's thread with an adaptive card containing severity,
  immediate actions, comms actions, and escalation path.
- **On runbook artefact generation (Step 3 hook):** reply with a card
  containing the match_type (retrieved / drafted / refused),
  runbook_id + cited_section (or refusal reason), the steps, and the
  escalate-to team handle.
- **On resolution (Step 4 hook):** reply with the review artefact —
  root cause, timeline summary, and links to the `.docx` downloads.
- **Config:** Teams incoming-webhook URL per service, held in env vars
  (`TEAMS_WEBHOOK_GHBFS`, `TEAMS_WEBHOOK_EYCDT`, `TEAMS_WEBHOOK_HEYP`).
  If no webhook is configured for the incident's service, log a warning
  and continue — never break the artefact flow because comms failed.
- **Persistence:** `Incident#teams_thread_id` plus per-artefact posted
  timestamps so we can retry a failed post without duplicating.
- **Delivery:** inline in the request/response cycle for the hackathon;
  move to a background job if it starts slowing artefact-generation UX.
- **Delivery mechanism note:** Teams "classic" Incoming Webhooks are
  deprecated (M365 retirement in 2025). Use a Power Automate Workflow
  with an "HTTP request received" trigger — same shape (POST JSON,
  get a message in the channel) but supported. Threaded replies via
  the Workflow's `chatMessage` output.

**Input:** each artefact-generation event.
**Output:** a Teams thread that mirrors the incident's full state, with
zero manual copy/paste from the on-caller.

**Review moment:** post an incident end-to-end and watch the Teams
channel — the on-caller should see all four artefacts appearing in
the same thread as they're produced.

---

## Step 6 — Incident dashboard + export

**Goal:** the demo landing page.

- `/incidents` index — GOV.UK table listing all incidents, status,
  service, artefact counts.
- Filter by status (open / resolved).
- "Export as Markdown" on each incident show page — packages the incident
  + all artefacts into a single downloadable `.md` (the thing a team
  would actually paste into Confluence / a GitHub PR).

**Review moment:** the dashboard tells the demo story on its own without
narration.

---

## Step 7 — Eval + non-functionals

**Goal:** we can prove the system behaves.

- Seeded eval set in `spec/evals/`:
  - 10 incident scenarios matched by the corpus → expect retrieval +
    citation
  - 5 scenarios with no matching runbook → expect refusal
  - 3 adversarial "sound-plausible-but-wrong" prompts → expect refusal,
    not hallucination
- RSpec harness that runs the eval and prints a scorecard.
- Cost + cache-hit-rate panel visible in the UI (per-call cost, cached
  tokens, uncached tokens).
- Basic guardrails: input length cap, secret-scan regex on paste
  (obvious API keys / email addresses redacted before sending to
  Claude).

**Review moment:** eval scorecard hits ≥85% retrieval accuracy, ≥90%
refusal accuracy, 0 hallucinations on adversarial tests.

---

## Stretch goals (Day 2 PM, only if the spine is green)

Each is a small, self-contained bolt-on.

### S1 — MCP server
- Expose `find_runbook`, `draft_review`, `generate_process` as MCP tools.
- Config for Claude Desktop.
- **Value:** the copilot lives where on-callers already are (Claude
  Desktop), not just in the web UI.

### S2 — Slack integration
- Mirror the Step 5 Teams integration for Slack (outgoing webhook +
  rich message + threaded replies via `ts` from the initial post).
- Slash command (`/incident-artefact <id>`) as a further stretch.
- **Value:** teams that use Slack instead of Teams can adopt the tool
  without moving to Teams.

### S3 — ISO 42001 alignment doc
- A `docs/compliance.md` mapping our controls (data minimisation,
  synthetic-only corpus, refusal-on-uncertainty, audit trail on every
  Claude call) to ISO 42001 clauses.
- Cheap to write, judged well.

### S4 — Streaming responses
- SSE endpoint so the artefacts render token-by-token rather than in a
  single blocking response. Better demo optics.

---

## Two-day allocation

### Day 1 — spine end-to-end
- **AM:** Step 0 (foundations) + Step 1 (intake + persistence).
- **PM:** Step 2 (process artefact) + Step 3 (runbook artefact with
  cached corpus).
- **End of day:** you can post an incident and get a process + runbook
  back, both persisted and cited. The spine is green.

### Day 2 — review + Teams + eval + demo
- **AM:** Step 4 (post-incident review) + Step 5 (Teams integration).
- **PM:** Step 6 (dashboard + export) + Step 7 (eval + non-functionals),
  then one stretch (S1 MCP or S2 Slack) only if Step 7 is green by 15:00.
- **PM last hour:** demo rehearsal, screenshots, kill any half-built
  stretch that isn't demoable.

Step 5 (Teams) is the demo's headline moment — the on-caller doesn't
have to touch the web UI to see the full picture. Protect that time.

---

## Team roles (three people)

- **A — Rails + UI + persistence.** Owns Steps 0, 1, 6 and the GOV.UK
  rendering of every artefact. Owns the demo's visible surface.
- **B — Claude + prompts + eval.** Owns Steps 2, 3, 4 prompt design,
  structured output schemas, and Step 7 eval harness. Owns the model
  behaviour.
- **C — Corpus + Teams + drafter.** Owns the synthetic runbook corpus,
  Step 5 Teams integration (posting, threading, adaptive cards), the
  drafter tuning, and any stretch integration (Slack / MCP). Owns the
  demo's memorable moments.

All three pair on the demo script late on Day 2.

---

## Non-goals (things we are explicitly not building)

- Real observability integration (Rollbar / Grafana / etc). The demo is
  chat-driven, not alert-driven.
- Vector DB — corpus lives in the cached system prompt.
- Auth / login. Single-tenant demo. If asked, "prod version would sit
  behind DfE SSO."
- Multi-turn conversational agent. Each artefact is a single Claude call
  with a structured output schema.
- Real Teams / Slack tenant — stretch integrations point at a personal
  test workspace, not a DfE tenant.

---

## Key risks and responses

1. **Rails 6.0 + Ruby 2.7.1 versioning pain on the lab VM.** Response:
   Step 0 is boot the app first — if the boilerplate won't start, we
   decide *at 09:30 on Day 1* whether to fight it or rebuild the shell
   in a lighter stack. Do not lose four hours to bundler.
2. **Prompt-engineering rabbit hole on the process artefact.** Response:
   time-box each prompt to 45 minutes; if the structured output isn't
   stable, ship the best version and move on.
3. **Corpus feels toy.** Response: Serena's GHBfS knowledge shapes the
   runbook content. Real failure modes, real owner names, real service
   language.
4. **Stretch creep on Day 2.** Response: stretch work only begins when
   Step 7 is green. If Step 7 isn't done by 15:00 Day 2, no stretch.
5. **Claude API cost during eval iteration.** Response: prompt caching
   on the corpus (~95% cache hit rate expected); per-call cost surfaced
   in the UI so we spot expensive prompts early.

---

## Review checklist for this plan

Before we start Step 0, we agree on:

- [ ] Chat-driven UX (user pastes incident) vs alert-driven (mock service
      fires events) — this plan is chat-driven; confirm.
- [ ] Three artefacts (process, runbook, review) is the right cut vs
      collapsing to two.
- [ ] Stretch priorities — of S1–S4, which one goes on the "if time" list?
- [ ] Team roles A / B / C — who owns which.
- [ ] Day 1 exit criterion — "post incident, get process + runbook back,
      both persisted and cited."
