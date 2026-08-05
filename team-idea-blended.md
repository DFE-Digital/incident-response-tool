# Team idea — GHBfS Incident Copilot (2-day build)

A Claude-powered incident copilot for the **Get Help Buying for Schools** (GHBfS)
delivery team. Blends Serena's operational pain (noisy Rollbar, no runbooks,
no incident response) with the retrieval-with-citations spine from the other
two scopes. Ruthlessly cut to what three people can actually ship in two days
by leaning on Claude as the engine, not just the assistant.

## The one-sentence pitch

For the GHBfS delivery team, a Claude-powered copilot that turns a live error
into a grounded next step from the team's runbooks — with citations, an
explicit refusal when no runbook covers it, and a draft runbook-update PR
generated from the incident timeline once it's resolved.

## Why this is achievable in two days

The 2-day win is architectural, not heroic: **the runbook corpus is small
enough to skip a vector database entirely**. Stuff the whole corpus (~15
synthetic runbooks, ~30–50k tokens) directly into Claude's context and use
prompt caching so repeat calls are cheap and fast.

That removes an entire class of infra (embeddings, vector store, chunking,
retrieval tuning) — a full day of work — while still giving us citations,
refusals, and grounded answers. For a real internal corpus at this scale it
is genuinely the right call, not a shortcut.

## Users and impact

- **Users:** the ~15-person GHBfS delivery team — devs, ops, product — plus
  a natural fit for any similar-sized DfE service team.
- **Frames the demo in a real service** — Serena's domain knowledge grounds
  the synthetic corpus in shapes judges recognise (framework lookups, DPS
  timeouts, quote submissions).
- **Impact statement:**
  - Mean time from alert to correct runbook step: 15+ min → under 30 sec
  - Runbook updates per incident: 0 → 1 drafted PR
  - New on-call anxiety: measurable via a "would you use this at 2am?"
    reviewer score

## What we're building

Three connected pieces around one spine. The spine is the copilot; the mock
service feeds it, the drafter closes the loop.

### 1. Mock GHBfS service (feeds the demo)

A tiny Node/Python service with 2–3 realistic endpoints:
`GET /frameworks`, `POST /quotes`, `GET /dps-status`. Emits structured JSON
logs. A "chaos" endpoint injects seeded failures (DB timeout, upstream 502,
validation error, auth failure) so we can trigger incidents on demand
during the demo.

### 2. Synthetic runbook corpus + incident copilot (the spine)

- **Corpus:** ~15 hand-written runbooks in Markdown covering the seeded
  failure modes plus a few decoys. Realistic GHBfS shapes: "DPS status API
  timeout," "framework search returning empty," "quote submission auth
  failure." Each has a clear ID, last-updated date, and owner.
- **Copilot API:** an endpoint that takes an alert or log excerpt and
  returns:
  - the next step to take,
  - the runbook ID + section it came from,
  - the runbook's owner + last-updated date,
  - or an explicit refusal: *"no runbook covers this — escalate to
    \<service owner\>"*.
- **How Claude is used:** the full runbook corpus is loaded into the system
  prompt with `cache_control` set. Every call hits the cache. A structured
  output schema forces citation + refusal behaviour.
- **Minimal UI:** a single page that shows the live log stream, lets you
  paste or click an alert, and displays the copilot's grounded answer with
  the cited runbook expanded next to it.

### 3. Post-incident runbook drafter (the memorable bit)

After an incident is marked resolved, the drafter takes the incident
timeline (alert + log window + actions taken + resolution note) and asks
Claude to produce a **diff against the existing runbook** — or a new
runbook stub if none existed. Output is a Markdown patch the team would
review and merge.

This is the "coworker, not search box" moment for the demo: it turns
one-off incident learning into permanent institutional knowledge.

## Two-day plan

### Day 1 — spine end-to-end

- **AM:** mock GHBfS service with 3 endpoints + chaos injector; structured
  logging; simple alert rule (error rate > threshold → fire).
- **AM:** synthetic runbook corpus authored (15 runbooks in Markdown).
- **PM:** copilot API — Claude call with cached corpus, structured output,
  citation-or-refusal contract.
- **PM:** minimal web UI wiring alert → copilot → answer + cited runbook.
- **End of day:** you can trigger a seeded incident and see a grounded
  answer with citation on screen.

### Day 2 — drafter + polish + eval + demo

- **AM:** runbook drafter — timeline in, Markdown diff out.
- **AM:** eval harness — 10 seeded incident scenarios; measure correct-step
  rate, correct-refusal rate, zero-hallucination check.
- **PM:** demo script rehearsal; UI polish; failure-mode handling; caching
  metrics visible (cache hit rate, latency, cost per call).
- **PM:** stretch if time — MCP wrapper so the copilot works inside Claude
  Desktop / Slack.

## Success criteria (what we'd demo)

On 10 seeded GHBfS-shaped incident scenarios:

- ≥85% return the correct runbook step with a valid citation
- ≥90% correctly refuse when the corpus doesn't cover the alert
- 0 cases where the copilot invents a step not in the corpus (adversarial
  tests in the eval)
- Drafter produces a runbook-update draft rated ≥4/5 for usefulness on 5/5
  resolved incidents by a reviewer
- Prompt-cache hit rate ≥95% on repeat calls; per-call cost visible in the
  UI

## Components (revised from Serena's sheet)

| Component | Status |
|---|---|
| A user interface | Core |
| An API | Core |
| A generative model (Claude) | Core |
| A vector database / RAG | **Not needed** — context-stuffing + prompt caching |
| An MCP server | Stretch |
| A sandboxed code-execution environment | Not needed |
| Containerisation | Core (single Dockerfile) |
| An automated CI/CD process | Stretch |
| Infrastructure as Code (Terraform) | Not needed for a 2-day demo |
| Cost-measurement controls | Core — surface per-call cost + cache hit rate |
| Error-measurement controls | Core — hallucination + refusal-rate tests |
| Security controls | Core — synthetic data only, no real logs, secret scanning |
| ISO 42001 alignment | Stretch — document the compliance posture |

## Key risks and responses

1. **Scope creep back into "dashboard + copilot + drafter as three
   products."** The copilot is the spine. Dashboard is a log viewer, not a
   Grafana clone. Drafter is a single Claude call, not a workflow engine.
2. **Hallucinated runbook steps.** Structured output schema requires a
   citation ID that must exist in the corpus; verify before returning.
   Adversarial tests in the eval.
3. **Synthetic corpus feels toy.** Serena's GHBfS domain knowledge shapes
   the runbooks — real failure modes, real owner names, real service
   language.
4. **Two-day timebox.** The spine (mock service + copilot + one runbook
   answered with citation) is Day 1's non-negotiable. The drafter is
   Day 2's non-negotiable. Everything else is stretch.
5. **Context-stuffing hits a corpus-size ceiling.** True — but at ~15
   runbooks we are nowhere near it, and the demo openly names this as a
   deliberate 2-day choice. Slide 1 of "what we'd build next" is
   "swap context-stuffing for retrieval as the corpus grows past ~100
   docs."

## Division of work (three people)

- **Person A — mock service + logging + alerting.** Owns the demo's
  "left-hand side" (something breaks).
- **Person B — copilot API + prompt engineering + eval harness.** Owns the
  Claude-facing spine.
- **Person C — UI + runbook corpus authoring + drafter.** Owns what the
  audience sees and the memorable Day-2 moment.

All three pair on the demo script.

## What Claude does that makes this a 2-day project instead of a 2-week one

- **Holds the entire corpus in context** — no vector DB build-out.
- **Prompt caching** — corpus is loaded once, cached, and reused across
  every call at a fraction of the cost.
- **Structured output** — the citation-or-refusal contract is enforced by
  the model, not hand-written parsers.
- **Drafter as a single call** — timeline in, Markdown diff out. No
  agent loop, no tool use, no orchestration layer.
- **Claude Code as the pair programmer** — scaffolding the mock service,
  the eval harness, and the UI while we focus on the corpus and the
  prompt.
