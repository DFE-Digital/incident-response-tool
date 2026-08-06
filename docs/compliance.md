# ISO/IEC 42001 alignment — incident-response-tool

Mapping the controls the tool implements today to the AI management
system standard **ISO/IEC 42001:2023**. Compiled during the two-day
graduation-project sprint, so read this as an early-stage self-
assessment, not a certified conformity statement.

Where a control is not yet implemented, the "Gap" column names it
explicitly — an incomplete mapping is more useful than a marketing
one.

---

## 1. Purpose and scope

- **What ISO 42001 is.** The first international standard for AI
  management systems (AIMS), published December 2023. Structure
  mirrors ISO 27001 (clauses 4–10 + Annex A controls). Focused on
  responsible use, risk management and lifecycle of AI-enabled
  systems.
- **Scope of this document.** Applies to the incident-response-tool
  Rails app in this repository. Covers the three Claude-backed
  artefact generators (process, runbook, review), the runbook
  corpus, and the surrounding data-handling controls.
- **Out of scope.** Anthropic's own model governance (they publish
  their own AI safety documentation); the DfE hosting environment
  (Azure Kubernetes Service, governed separately).

## 2. AI system overview

The tool is a single-user web application that helps DfE on-callers
handle an incident. Three uses of AI, each a separate Claude call
with its own prompt and structured JSON output:

| Artefact | Purpose | Human-in-the-loop |
|---|---|---|
| Process | Draft a "what to do right now" checklist (severity, immediate actions, comms actions, escalation path) | The on-caller decides whether to follow it; the tool does not act on the plan. |
| Runbook | Match the incident against a fixed synthetic corpus of ~10 runbooks; return retrieved / drafted / refused | The on-caller executes the steps in a real terminal; the tool does not run commands. |
| Review | After the incident is resolved, draft the header + timeline of the DfE incident-report template | The retrospective meeting fills in root cause and reflective questions — the tool leaves those blank by design (see section 4.4). |

The model is Anthropic Claude Opus 4.7. No fine-tuning; prompts are
static (versioned in git) with prompt caching for the runbook corpus.

## 3. Architecture — Cache-Augmented Generation (CAG), not RAG

The tool is often mistaken for a retrieval-augmented generation (RAG)
system because it "answers from a corpus with citations". It isn't.
It is a **Cache-Augmented Generation (CAG)** system.

### The distinction

- **RAG:** a separate retrieval step (vector similarity, BM25, or a
  hybrid) narrows a large corpus down to a small relevant subset,
  which is then inserted into the LLM's context.
- **CAG:** the whole corpus lives in the LLM's context on every
  request. Prompt caching (Anthropic's `cache_control:
  {type: "ephemeral"}`) amortises the input cost across many calls
  — the first call pays to write the cache; subsequent calls read
  it at roughly 10× less per token. Retrieval happens implicitly
  via the LLM's own attention over the full context.

### Why CAG for this system

The runbook corpus (`db/seeds/runbooks/*.md`) is ~5 000 tokens
across 10 files. That is comfortably inside Claude Opus's context
window (200k tokens) and small enough that a full-context
comparison per query is preferable to a similarity-thresholded
narrow.

### Trade-offs

| | CAG (this tool) | RAG |
|---|---|---|
| Infrastructure | Prompt cache only | Vector DB + embedding model + chunker |
| Retrieval accuracy on small corpora | Very high — the LLM sees the whole corpus every time | Depends on embedding quality and chunk boundaries |
| Cost per query | Higher without caching; ~1/10 with cache-hit | Cheap per query, but infra + storage costs |
| Ceiling | ~200 000 input tokens on Claude Opus | Effectively unbounded |
| Corpus refresh | Invalidates the cache; next call re-writes it | Re-embed the changed docs only |
| Attack surface for prompt injection | Same as any LLM call | Add: poisoned embeddings, index tampering, retrieval-side prompt injection |

### Implications for this compliance mapping

- **Fewer suppliers to assess (A.10.3).** No embedding-model vendor,
  no vector-DB vendor. Anthropic is the only AI-adjacent third
  party.
- **Simpler data provenance (A.7.4).** The corpus is exactly the
  set of files committed to git. There is no derived embedding
  store to keep in sync or protect.
- **Fewer failure modes (A.6.2.5).** No retrieval-quality
  failures, no chunking-boundary failures, no similarity-threshold
  tuning. The evaluation set (`spec/evals/`) exercises the LLM's
  reasoning directly.
- **Direct upper bound on corpus size.** CAG will not scale past
  ~200 000 input tokens. When the corpus grows beyond a few
  hundred runbooks, migration to RAG becomes forced, not optional
  — flagged as a known gap.
- **Live cache-hit rate is measurable.** Each artefact record
  stores `cache_read_input_tokens` /
  `cache_creation_input_tokens`. `AnthropicPricing.summary_line`
  surfaces the hit rate in the UI — a first-order signal that CAG
  is functioning as designed.

Empirically the hit rate in normal use is ≥95% once the corpus is
warm (verified by the eval run in `spec/evals/`).

## 4. Data protection posture

- **No production data.** The corpus in `db/seeds/runbooks/*.md` is
  synthetic — hand-written for the sprint using GHBfS-shaped
  scenarios; no real runbooks, no real supplier data, no real user
  identities.
- **No PII ingest.** Incident descriptions are the only user input.
  `PromptSanitizer` (`app/services/prompt_sanitizer.rb`) redacts
  Anthropic / OpenAI / AWS API keys, Bearer tokens and email
  addresses before any description reaches Claude. Documented on
  the intake form ("API keys and email addresses are automatically
  redacted").
- **Length caps.** `Incident` validation limits title ≤200 chars,
  description ≤10 000 chars — bounds input volume both for cost
  and for reducing the chance of an accidentally-pasted secret
  slipping through the sanitiser.
- **No user accounts.** The MVP is single-tenant; no user data is
  stored. Real deployment would sit behind DfE Sign-in.

## 5. Mapping to Annex A controls

Controls listed in the order they appear in ISO 42001:2023 Annex A.
For each, our evidence + any gap. Controls not listed are either not
applicable to a single-app MVP or covered indirectly by another
control we do implement.

### 5.1 A.2 — Policies related to AI

| Control | Evidence | Gap |
|---|---|---|
| A.2.2 AI policy | `team-idea-blended.md` states the "no-vector-DB, prompt-cache, refusal-over-invention" architectural principles the tool is built on. `plan.md` names blameless voice, citation-or-refusal, and data-minimisation as goals. | No standalone written policy. For a real deployment this doc + `plan.md` would be lifted into a proper DfE AI-usage policy. |
| A.2.3 Alignment with other policies | Aligns with DfE tooling defaults (kubectl / Azure, not CloudFoundry) and the DfE Teacher Services incident playbook — see `docs/artefact_examples/`. | — |

### 5.2 A.3 — Internal organisation

| Control | Evidence | Gap |
|---|---|---|
| A.3.2 AI roles and responsibilities | `plan.md` "Team roles (three people)" section names owners for Rails/UI, prompts/eval, and corpus/Teams integration. | Only a team-of-three, not a full RACI. |

### 5.3 A.5 — Assessing impacts of AI systems

| Control | Evidence | Gap |
|---|---|---|
| A.5.2 AI system impact assessment | `team-idea-blended.md` scopes intended vs unintended use; `plan.md` "Non-goals" and "Key risks" sections list what the tool is not for and where it could go wrong. | Impact assessment is informal — no separate signed-off document. |
| A.5.3 Assessing impacts on individuals | The tool does not affect individuals directly — its outputs are advisory drafts an on-caller reads. | Downstream DfE staff (technical leads named in the post-incident review) are named by the human filling the form, not inferred by Claude. |
| A.5.4 Assessing societal impacts | Refusal-over-invention default is the primary societal safeguard (see A.6.2.5). The corpus is synthetic so no organisational data leaks in incident reports produced. | Bias testing not performed — the corpus is uniform in voice and no demographic axes are exercised. |

### 5.4 A.6 — AI system lifecycle

| Control | Evidence | Gap |
|---|---|---|
| A.6.2.2 Development process | The full development log is in `docs/ai-log.md` — newest at top, each entry states what happened + what was decided + what's left open. Every change is a git commit with a full-context message. | — |
| A.6.2.3 Design and development documentation | `plan.md` (per-step design), `team-idea-blended.md` (scope), `docs/artefact_examples/` (grounding references), `docs/teams-integration-setup.md` (integration setup). | — |
| A.6.2.4 Verification and validation | `spec/evals/runbook_scenarios.yml` + `lib/tasks/eval.rake` — 10 curated scenarios across three buckets (retrieval / draft / refuse). Verified end-to-end pass rate: 10/10, retrieval accuracy 100%, refusal accuracy 100%, zero hallucinated runbook_ids. Cost per full eval run: ~$0.96. | Eval set is small; no continuous eval on prod inputs; no adversarial-prompt bucket beyond the two refusal scenarios. |
| A.6.2.5 AI system requirements | The Claude prompts encode the requirements explicitly: (a) refuse over invent, (b) cite corpus runbooks by id, (c) never emit CloudFoundry commands, (d) blameless voice for reviews, (e) only fill header+timeline for reviews. | — |
| A.6.2.6 AI system deployment | Local Docker + docker-compose only. `README.md` and `docs/teams-integration-setup.md` cover how to run it. | No production deployment yet — a real DfE deployment would need environment separation, secrets management, and observability. |
| A.6.2.7 AI system operation and monitoring | Per-artefact usage tokens + cache-hit-rate + cost displayed on the incident show page (`AnthropicPricing.summary_line`). Log lines from `TeamsNotifier` for delivery outcomes. | No aggregated dashboard; no drift detection; no alerting on cost or error spikes. |
| A.6.2.8 AI system technical documentation | `README.md` (setup + stack), `plan.md` (feature spec), `docs/ai-log.md` (change history), `docs/compliance.md` (this doc). | — |

### 5.5 A.7 — Data for AI systems

| Control | Evidence | Gap |
|---|---|---|
| A.7.2 Data for AI systems (data acquisition) | Runbook corpus is hand-authored — no acquisition from external sources; nothing scraped. All 10 files in `db/seeds/runbooks/` are version-controlled and reviewable. | — |
| A.7.3 Data quality | Corpus follows a documented shape (`docs/artefact_examples/govuk_task_runbook_example.md`) — YAML frontmatter with id, owner, last_updated, symptoms; body with Pre-requisites → action-phrased headings → inline commands → verification. Uniform vocabulary (DfE playbook roles). | Only one style is exercised; no diverse-authorship test corpus. |
| A.7.4 Data provenance | Fully synthetic. `plan.md` "Non-goals" explicitly rules out real supplier / user data. No PII in the corpus. | — |
| A.7.5 Data preparation | `PromptSanitizer` (secrets + email redaction). `RunbookCorpus.formatted_for_prompt` builds the deterministic system-prompt string committed to git. | — |

### 5.6 A.8 — Information for interested parties

| Control | Evidence | Gap |
|---|---|---|
| A.8.2 System documentation and information for users | Intake form declares "API keys and email addresses are automatically redacted". The show page tags each artefact by outcome (Retrieved / Drafted / Refused). Drafted-from-scratch artefacts are labelled as such — the user is never told the AI matched a runbook when it didn't. The review artefact opens with the retrospective prime directive quote verbatim so users know the intent. | No standalone end-user guide beyond `README.md`. |
| A.8.4 Communication of incidents | Refusal reasons are surfaced in the UI ("No runbook covers this — escalate to @…"). Teams integration (Step 5) posts each artefact into the incident channel with structured Adaptive Cards. | — |

### 5.7 A.9 — Use of AI systems

| Control | Evidence | Gap |
|---|---|---|
| A.9.2 Intended use | Documented in `team-idea-blended.md` "Three pillars" and `plan.md` "Product in one sentence". Not for: alert-driven automation, taking action on the plan, replacing the on-caller (all called out as non-goals). | — |
| A.9.3 Objectives for responsible use of AI | Refusal-over-invention default (Step 3 prompt); AI drafts only the factual header of the review, humans discuss the reflective questions (Step 4); blameless voice enforced by prompt (Step 4); all outputs are advisory — no code is executed. | — |
| A.9.4 Responsible use documentation | This document. | — |

### 5.8 A.10 — Third-party and customer relationships

| Control | Evidence | Gap |
|---|---|---|
| A.10.2 Allocation of responsibilities | Anthropic is the model provider (responsible for model behaviour and safety); we are the AI-system builder (responsible for prompts, corpus, guardrails, UX and this AIMS mapping). | — |
| A.10.3 Suppliers | Third-party dependencies are: Anthropic API, GOV.UK Notify (referenced in one runbook), Microsoft Teams (integration target). All listed in `Gemfile` / `package.json` / plan.md. | Formal supplier assessment not performed — hackathon MVP. |

## 6. Known gaps

Consolidated list of everything flagged in the Gap columns above:

1. **No standalone AI-usage policy document.** Would lift from
   `plan.md` and this doc.
2. **Informal impact assessment.** No signed-off assessment separate
   from `team-idea-blended.md` / `plan.md`.
3. **Small eval set, no adversarial expansion.** 10 scenarios; would
   grow to at least 30 with a jailbreak/prompt-injection bucket
   before real deployment.
4. **No production deployment / observability**. Local Docker only.
5. **No aggregated cost / usage dashboard.** Per-artefact numbers
   visible; no service-level or per-day totals.
6. **No drift detection or continuous eval on production inputs.**
7. **No bias testing on outputs.** Corpus is uniform in voice.
8. **No formal supplier assessment.** Third parties are informally
   documented.
9. **No end-user guide beyond `README.md`.**

## 7. Change log

- 2026-08-06 — initial draft (David Feetenby). Reflects the state
  of the tool at the end of Step 7 on `david/step-seven`.
- 2026-08-06 — added section 3 explaining the architecture as
  Cache-Augmented Generation (CAG), not RAG, with the trade-offs
  table and the compliance implications (fewer suppliers, simpler
  data provenance, fewer failure modes, direct upper bound on
  corpus size). Renumbered subsequent sections.
