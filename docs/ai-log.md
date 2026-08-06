# AI log — W12 hackathon / graduation project

Running log of what Claude and I have done together on the grad project.
Newest entries at the top. Each entry names what happened, what was
decided, and what's left open.

**We are building the incident-response-tool inside
`~/Documents/my-work/w12-hackathon/incident-response-tool/`** — this is the
project working directory for the grad-project two-day sprint. The cloned
`DFE-Digital/incident-response-tool` Rails repo is the starting point.
Docs live inside it: this log in `docs/ai-log.md`, `team-idea-blended.md`
at the repo root, `plan.md` at the repo root.

---

## 2026-08-06 — Session 5 (Opus 4.7)

Cross-cutting fixes + Step 6 (dashboard). Retrospective — some of this
was actually 2026-08-05, logged today.

### Retrospective — unblocking `make dev` on the lab VM

- Podman needed `docker.io` as an unqualified-search-registry — added
  `~/.config/containers/registries.conf` (user-level only).
- Upstream deleted `Gemfile.lock`; regenerated with Ruby 3.2 + bundler
  2.4.22 via `podman run --rm ruby:3.2-alpine bundle lock`.
- The image bakes `bundle config set without 'development test'`, but
  dev compose uses `RAILS_ENV=development` and needs dev+test gems.
  Fixed on the compose side (Dockerfile untouched) — added
  `BUNDLE_WITHOUT=""`, `bundle config unset without`, `bundle install`,
  and `apk add build-base` (runtime image lacked `make`) to the
  container command in `docker-compose.dev.yml`.
- `config.hosts << /.*\.labs\.decoded\.com/` already whitelisted the
  lab proxy hostnames — so both `https://3000-<host>.labs.decoded.com/`
  and `/proxy/3000/` work once web is up.

### Step 2 polish attempt (reverted)

- Converted the three process-artefact lists on the show page into a
  GOV.UK task list with per-item status (not started / in progress /
  done). Extended the serialized arrays to `{"label", "status"}`
  hashes; added `items_for(category)` + `advance_status!` on
  `ProcessArtefact`; new `POST /incidents/:incident_id/process_artefact/advance`
  route + `_task_list_section.html.erb` partial.
- Reverted the whole thing on user request — back to plain bullets +
  ordered list. Flattened the one persisted hash-form artefact via
  `bin/rails runner`.

### Downloadable .docx artefacts (all three)

- Added a "Download as Word document" secondary button on each
  artefact section of the incident show page (process, runbook,
  review).
- Started as HTML-wrapped-as-.doc (zero-dep hack); user switched to a
  real `.docx` via the `htmltoword` gem.
- First cut wouldn't open in Microsoft Word. Diagnosis: each
  `build_doc` was returning a full `<!DOCTYPE html><html
  xmlns:o="…">…<body>` document — legacy from the .doc-as-HTML
  approach. htmltoword's XSLT wraps whatever you give it in a docx
  envelope; the wrapper elements corrupted `document.xml` inside the
  zip and Word refused it.
- Fixed by stripping all three `build_doc` methods to plain HTML
  fragments — just `<h1>`, `<p>`, `<ul>`, `<table>` etc. Also
  dropped `<hr>` (no clean WordML equivalent) and swapped
  `<blockquote>` in the review for `<p><em>…</em></p>`
  (htmltoword's blockquote handling is inconsistent).
- **Not verified end-to-end** after the fix: the app has been down
  through the session, so this needs a `make dev` + click-through
  before we trust it.

### Blank-answer validation on the post-review form

- Added `presence: true` validations to `ReviewArtefact` for
  `technical_lead`, `comms_lead`, `support_lead`, `timeline_notes`,
  `resolution_notes` — GDS-style imperative messages
  (`"Enter the technical lead"`, etc.) rather than Rails' default
  "can't be blank".
- No controller or view changes needed: form already renders
  `f.govuk_error_summary` and the controller already rescues
  `ActiveRecord::RecordInvalid` → re-render `:new` with
  `unprocessable_entity`.

### Process artefact generates on incident create

- Moved `ClaudeProcessService.new(@incident).call` from the "Generate
  process" button to `IncidentsController#create`, immediately after
  `@incident.save`.
- Wrapped in `begin/rescue` (parse error, missing key, generic
  `StandardError`) so a flaky LLM call can't undo the incident create.
  On failure the user still lands on the show page and the existing
  "Generate process" button acts as a retry — no template changes.
- Trade-off: the new-incident submit now blocks for the length of the
  Claude call (~3–10s). Same latency as the button click it replaces,
  just moved earlier. Async later = ActiveJob adapter change.

### Step 6 — incident dashboard (/incidents index)

- New `IncidentsController#index`; scoped by `?status=open|resolved`,
  eager-loads the three artefact associations to avoid N+1.
- Root route moved from `incidents#new` to `incidents#index` so the
  dashboard is the demo landing page.
- New `app/views/incidents/index.html.erb`: primary "Report a new
  incident" button, filter row, and GOV.UK table with columns
  Ref (`INC-#{id}`), Title, Service, Reported, Status tag,
  Artefacts (`N / 3`).
- Skipped plan.md's "Export as Markdown" bullet per user instruction
  — the per-artefact .docx download already covers export needs.

### Filter polish to GDS standards

- Rewrote the filter as a semantic `<nav aria-label="Filter incidents
  by status">` wrapping a `<ul class="govuk-list">`.
- Current filter is a non-linked `<strong aria-current="page">` —
  matches GDS's "the page you're on shouldn't be a link" pattern.
- Non-current filters use `govuk-link` + `govuk-link--no-visited-state`
  (filters get clicked repeatedly, shouldn't turn purple).
- Counts styled with `govuk-!-colour-secondary` — proper GDS secondary
  text colour, replacing the earlier misuse of `.govuk-hint`.

### Open questions / next up

- **Verify `.docx` files open in Word** after the wrapper strip — app
  was down through this session so it wasn't tested.
- **Step 7** (eval + non-functionals) is the last unshipped plan item:
  seeded eval set in `spec/evals/`, RSpec scorecard, cost + cache-hit
  panel, input length cap + secret-scan guardrails.

---

## 2026-08-06 — Session 4 (Opus 4.7)

### Step 5: Teams integration (main goal, not stretch)

Promoted Teams from S2 stretch into Step 5 of `plan.md` before building.
Rationale: the DfE Teacher Services playbook (see
`docs/artefact_examples/dfe_incident_playbook_reference.md`) treats the
Teams thread as where an incident actually lives — moving it out of
"if time" reflects that. Also the feature that most reduces on-caller
toil (zero copy/paste). Dashboard → Step 6, eval → Step 7.

Implementation on `david/step-five`:
- `TeamsNotifier` service with four class methods
  (`incident_opened` / `process_generated` / `runbook_generated` /
  `review_generated`). Each builds an Adaptive Card and POSTs to the
  incident service's webhook.
- Per-service webhook env vars: `TEAMS_WEBHOOK_GHBFS`,
  `TEAMS_WEBHOOK_EYCDT`, `TEAMS_WEBHOOK_HEYP`. Missing webhook → log
  and skip. HTTP failure → log warning, don't blow up the artefact
  flow. Applies to all four hook points.
- Delivery mechanism: **Power Automate Workflow** with an "HTTP
  request received" trigger mapped to "Post adaptive card in a chat
  or channel". Classic Incoming Webhooks are being retired in 2025,
  so we skipped them.
- Payload shape: standard Teams `{type: message, attachments:
  [{contentType: application/vnd.microsoft.card.adaptive, ...}]}`.
  Adaptive Card v1.4, TextBlock + FactSet + Container + Action.OpenUrl.
- Wired into `IncidentsController#create`,
  `ProcessArtefactsController#create`,
  `RunbookArtefactsController#create`, and
  `ReviewArtefactsController#create` (post-transaction for the review
  so a Claude failure doesn't leave a Teams post announcing a
  resolution that got rolled back).
- Added `teams_thread_id` column to `incidents` for future threading
  via Graph API. Not used yet — first pass posts each artefact as a
  fresh message with the incident ID in the title, which visually
  groups them without needing OAuth app registration.
- For local testing without setting up Teams, point the env var at
  a webhook.site URL to inspect payloads.

### Open questions / next up
- Threading via Graph API (still a real gap — messages don't reply
  to each other, just share a title prefix).
- Step 6 (dashboard + export) and Step 7 (eval scorecard) are still
  pending; user hasn't started either yet.

---

## 2026-08-05 — Sessions 2–3 (Sonnet 4.6 → Opus 4.7)

Steps 1 through 4 shipped across a long working day, with several
detours to fix boilerplate rot.

### Step 1: Incident intake form

Model swap to Sonnet 4.6 mid-session for the intake work. Built the
`Incident` model + form + show page + persistence. Landed on `david/step-one`.

- `Incident(title, description, service, status, timestamps)` with
  four service options (later broadened; see below).
- GDS formbuilder view (`form_with model: @incident, local: true,
  builder: GOVUKDesignSystemFormBuilder::FormBuilder do |f|`).
- Rails 6 form defaults to `data-remote="true"` — clicking submit
  did nothing until we added `local: true`. Worth remembering: any
  new form on this stack needs it.
- API mismatch bumps discovered along the way in govuk-components
  2.0.1: `govuk_form_with` doesn't exist (use `form_with builder:`);
  `govuk_error_summary` must be called on the form builder inside
  the form block; `govuk_summary_list` API differs from earlier
  versions (fell back to plain `dl/dt/dd` with GDS classes).

### Step 2: Process artefact (handed off to Serena)

Wrote the initial `ProcessArtefact` model + `ClaudeProcessService` +
controller + partial view rendering, then handed the step over to
teammate Serena for polish + the Word-doc export feature. Serena's
work landed on `serena/step-2` and `serena/edit-docker-compose`.

Key decisions carried over from Step 2:
- Claude call uses plain `Net::HTTP` — the official `anthropic` gem
  requires Ruby ≥3.2 (we started on 2.7.4). Kept even after the
  Ruby upgrade because it works and there's no reason to add a dep.
- Structured JSON output via prompt shape, no tool-use — simpler,
  easier to reason about failures.
- Severity ladder became **P1/P2/P3** (not P1–P4) after the DfE
  Teacher Services playbook reference — see below.

Serena added the **Word-doc download** (`GET /incidents/:id/process_artefact/download`).
Initial implementation was HTML-with-`.doc`-extension + `application/msword`
MIME (Word opens it leniently). Later upgraded to real `.docx` — see
below.

### Step 3: Runbook artefact + corpus + prompt caching

Landed on `david/step-three`. This step is where the "no vector DB"
architectural bet paid off:

- Synthetic corpus of **10 runbooks** in `db/seeds/runbooks/*.md`,
  each with YAML frontmatter (runbook_id, owner, last_updated,
  symptoms) + Markdown body in the shape from
  `docs/artefact_examples/govuk_task_runbook_example.md`. Total
  ~5k tokens — sits comfortably in Claude's prompt cache.
- `RunbookCorpus` loader reads all `.md` files and formats them for
  the system prompt.
- `ClaudeRunbookService` sends the corpus as a
  `cache_control: {type: "ephemeral"}` block, so subsequent calls
  within ~5 minutes hit the cache and cost ~10% of the first call.
- Three-state output: `retrieved | drafted | refused`. Verified
  end-to-end with real Claude calls:
  * DPS timeout incident → retrieved (green tag, correct runbook_id)
  * Contract award API timeout → drafted from DPS pattern (yellow)
  * Fire alarm in office → refused, escalated to `@ghbfs-service`
- Later relaxed refusal criterion (user pushback: "if no runbook
  exists i want it to make one"). Now refuses only for
  clearly-non-operational reports; anything technical gets drafted.

### Detour: Ruby 3.2 + logger + sass + node — versioning cascade

Trying to `make build` after adding runbook code turned into a rabbit
hole. Chain of issues + fixes:

1. **`sass@1.102.0` needs Node ≥20.19.0** — Dependabot had bumped
   `govuk-frontend` 3.12 → 6.4 and `webpack-dev-server` 3 → 6 in
   the archived boilerplate. Pinned `govuk-frontend=3.12.0`,
   `sass=1.57.1` via `resolutions`, rolled `webpack-dev-server`
   back to `^3.11.2`.
2. **`uninitialized constant Logger`** on assets:precompile.
   Rails 6.1.7.10 regressed the load order in
   `active_support/logger.rb` — `require "logger"` moved to AFTER
   `require "active_support/logger_silence"`, so `Logger::Severity`
   isn't defined when `logger_thread_safe_level` runs. Fix: prepend
   `require "logger"` in `config/boot.rb`, `bin/webpack`, and
   `bin/webpack-dev-server`. Present on both Ruby 2.7 and 3.2 —
   not a Ruby version bug.
3. **`error:0308010C:digital envelope routines::unsupported`** —
   webpack 4 uses MD4 hashing, unsupported in OpenSSL 3 (ships with
   Node 18 on Alpine). Fix: `NODE_OPTIONS=--openssl-legacy-provider`
   on the `assets:precompile` step in the Dockerfile.
4. **Upgraded Ruby 2.7.4 → 3.2** at user's suggestion to escape
   the logger/gem-compat mess. Bundler bumped to 2.4.22. All the
   above fixes still needed but system now much cleaner.

The Dependabot bumps that caused this were pre-existing on master —
easy trap for anyone else cloning this repo cold.

### Detour: bundler/dev-mode container tuning

- `docker-compose.dev.yml` mounts source over `/app` with an anonymous
  volume on `/app/public/packs` to preserve the baked precompiled
  assets. `DATABASE_URL` set in env overrides `database.yml` (which
  defaults to a Unix socket in dev).
- Bundler 2.4 in the Ruby 3.2 image is stricter about `Gemfile.lock`
  — the image-time `bundle config set without` didn't stick through
  the source mount. Fix: `BUNDLE_WITHOUT=development:test` env var.
- Serena later switched to `bundle config unset without && bundle
  install` on startup so dev/test gems are available inside the
  container. Takes ~90s on first boot; subsequent boots reuse the
  installed gems.

### Detour: .docx generation (not `.doc`)

Serena's original process-download shipped as HTML-with-`.doc`
extension. User asked for real `.docx`. Renaming to `.docx` alone
would trigger Word's "wrong format" warning (OOXML has a strict
ZIP/schema check, unlike `.doc` which accepts HTML). Solution:

- Added `htmltoword` gem — takes our existing HTML and produces
  valid OOXML `.docx` via bundled XSLT.
- Both download actions changed one line each:
  `send_data Htmltoword::Document.create(html), type:
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document"`.
  Verified: downloaded files are ZIP archives with the expected
  `[Content_Types].xml` / `word/document.xml` structure.
- `Htmltoword::Document.create` returns the raw bytes as a String;
  don't call `.string` on it.

### Detour: govuk-components 5.x breadcrumbs API change

After the Ruby 3.2 lockfile regeneration, `govuk-components` bumped
from 2.0.1 to 5.11.1. The old shape
`govuk_breadcrumbs(breadcrumbs: [{text: "Home", href: root_path}, ...])`
fell through to `text.to_s` and printed literal Ruby hashes at the
top of every page. Fix: use the Hash form
`govuk_breadcrumbs(breadcrumbs: { "Home" => root_path, "Current" => nil })`.

### Detour: CSS not loading via the lab proxy

Symptom: HTML page loaded, but the browser 404'd on
`https://code-lab8103.labs.decoded.com/packs/css/application.css`.
Curl from localhost returned 200, so Rails was serving it correctly —
the lab proxy at port 443 wasn't forwarding `/packs/` requests to
the Rails app. Fix (per the memory rule): use the direct-port URL
`https://3000-code-lab8103.labs.decoded.com/` which routes everything
to port 3000. Not a code change.

Also fixed `Rails::ApplicationController::BlockedHost` for the lab
domain by adding
`config.hosts << /.*\.labs\.decoded\.com/` in `development.rb`.

### Reference artefacts added to shape Claude output

Added two grounding docs in `docs/artefact_examples/` from user-supplied
links (`useful_links.txt`):

- `dfe_incident_playbook_reference.md` — DfE Teacher Services
  incident playbook. Five-phase lifecycle. P1/P2/P3 severity ladder
  with product-specific caps. Comms/tech/support-lead role trio
  (with delivery manager / programme delivery manager / deputy
  director / service owner as escalation). Comms surface is Teams
  + SharePoint (not Slack). Grounds Steps 2 and 4.
- `govuk_task_runbook_example.md` — GOV.UK Publishing mobile
  remote-config runbook. Pre-requisites → action-phrased headings
  → inline commands → verification → cache-purge note. Access
  control via GitHub team membership (`@team-handle`), not named
  people. Grounds Step 3.

Also updated `plan.md` Step 4 to match the DfE
`Incident report template.docx` shape exactly — six named review
questions plus user_impact + root_cause, with the retrospective
prime directive quote preserved verbatim in the rendered output.

### Scope broadening: three services, not just GHBfS

User asked to expand from just GHBfS to also include Child Development
Training (EYCDT) and Help for Early Years Providers (HEYP) — the
user works on early-years-adjacent DfE services. Changes:

- `Incident::SERVICES` = GHBfS, CDT, HEYP, Other.
- `ClaudeRunbookService` prompt updated to name all three as in-scope
  and to escalate to the correct `@<service>-tech` / `@<service>-service`
  handles. Refusing an operational incident because it's on CDT or
  HEYP rather than GHBfS is explicitly disallowed.
- Runbook corpus stayed GHBfS-shaped; for CDT/HEYP incidents Claude
  now drafts from general SRE practice rather than refusing.

### Infrastructure vocabulary: CloudFoundry → Azure Kubernetes

User: "we are no longer using cloudfoundry". GOV.UK PaaS was
decommissioned in Dec 2023; DfE is on AKS. All 10 runbook corpus
files rewritten to use `kubectl exec` / `kubectl logs` / `kubectl
rollout restart` / `kubectl rollout undo` and `az` for cloud-level
ops. Pre-requisites lines updated from "Cloud Foundry CLI" to
"`kubectl` configured against the `<service>-production` AKS
namespace". Drafting prompt got a "Tooling" rule that explicitly
bans emitting any `cf ...` command. Saved as a persistent memory
`dfe-infrastructure-stack` so future sessions default correctly.

### Step 4: Post-incident review

Landed on `david/step-four`. Only available once an incident is
marked resolved. Show page gets a third "Post-incident review"
category with a "Mark resolved" button that opens a form for lead
names, timeline notes and resolution notes. Submitting the form
persists the user-provided fields, calls Claude to draft the review,
and marks the incident resolved — all in one transaction so a Claude
failure rolls the resolution back.

Initial pass had Claude draft the entire DfE template (user_impact,
root_cause, four reflective questions, three action lists,
runbook_diff). User pushback: "review document should only fill in
up to timeline and no further, the rest should be left to users to
fill in". Rewrote the prompt to return only `user_impact` +
`timeline` — the reflective sections are for the retrospective
meeting, not for AI. Downloaded .docx has the section labels + empty
answer lines / three empty bullets each, ready for the team to work
through together.

### Design polish: collapsible artefacts

All three artefact categories (process, runbook, review) wrap their
generated content in `<details class="govuk-details">` defaulting
closed. Section headings always visible; users click "Show process /
runbook / review" to expand each independently. Uses native
`<details>` for progressive enhancement + govuk-frontend JS for the
chevron animation.

### PR + branch topology

Rebases and cherry-picks kept branches in sync as teammates worked
in parallel:
- `david/step-one` → merged into master as PR #13.
- `david/step-three` was rebased after `serena/edit-docker-compose`
  merged in — one conflict on `config/routes.rb` (both branches
  added a route), resolved by keeping both entries. Force-push with
  `--force-with-lease` after rebase.
- Cherry-picked Serena's `Add gemfile lock` commit onto step-three
  when it was needed before that PR merged.
- Later rebased `david/step-three` onto `serena/step-2` — Serena
  added a Word-download action to the process artefact controller
  that we merged additively.
- Step 4 landed on `david/step-four`, merged as PR #20.

### Persistent memory added
- `dfe-infrastructure-stack` — DfE moved off CloudFoundry/GOV.UK PaaS;
  use kubectl / Azure examples, not `cf` commands.
- `feedback_no_claude_coauthor` (earlier session) — never add
  Co-Authored-By: Claude trailers.

### Open questions / next up (as of end of Aug 5)
- Step 5 (Teams) — the promoted-from-stretch main goal.
- Step 6 (dashboard + export) + Step 7 (eval) still pending.

---

## 2026-08-05 — Session 1 (Opus 4.7)

### Restored session work after accidental wipe
- Working tree was cleaned + untracked files deleted (likely via VS Code's
  "Discard All Changes" + "Delete Untracked" from the Source Control
  menu). Nothing recoverable from reflog / fsck / stash / VS Code Local
  History.
- Reconstructed from conversation context: `plan.md`,
  `team-idea-blended.md`, `docs/ai-log.md`, plus the three Step-0
  build-config fixes (Dockerfile, docker-compose.yml, package.json).
- **Lesson:** commit early on `david/documents`, even a WIP commit, so
  this can't reoccur.

### Sorted out VS Code source-control confusion
- Symptom: Source Control panel didn't show `incident-response-tool` even
  though we were editing files inside it.
- Root causes (uncovered in order):
  1. A phantom `~/Documents/.git` (empty, no commits, no remote) —
     someone had run `git init` at the Documents root, probably by
     clicking VS Code's "Initialize Repository" button in the empty
     Source Control panel. Deleted.
  2. `~/Documents/.git` got recreated a second time — same trap. Deleted
     again.
  3. VS Code's default subfolder scan only looks 1 level deep. Enabled
     `git.autoRepositoryDetection: "subFolders"` and set
     `git.repositoryScanMaxDepth: 4` in
     `~/.config/Code/User/settings.json` so it can reach
     `my-work/w12-hackathon/incident-response-tool/` (3 levels down).
- Also noted: `hackathon-week3-room6-` was deleted by user during
  debugging (they no longer needed it).

### Confirmed project working directory + repo
- Team is building on top of the cloned `DFE-Digital/incident-response-tool`
  repo, inside `~/Documents/my-work/w12-hackathon/incident-response-tool/`.
- Grad-project memory updated to reflect the pivot (from generic
  "policy colleague in a box" framing → GHBfS-grounded incident copilot,
  Serena's operational context).
- `team-idea-blended.md` + `plan.md` sit at repo root; this log lives in
  `docs/`.

### Wrote plan.md
- Sequenced 7-step plan (Steps 0–6) at repo root: foundations → intake →
  process artefact → runbook artefact → review artefact → dashboard →
  eval. Five stretch goals (S1–S5).
- Confirmed chat-driven UX over alert-driven (per user brief).
- Day-1 exit criterion recorded: post an incident, get process + runbook
  back, both persisted and cited.

### Installed Ruby (via Docker/podman)
- Picked path: **Docker via the repo's Dockerfile** (avoids OpenSSL 3
  pain on Ubuntu 24.04 with Ruby 2.7.x).
- Pulled `ruby:2.7.4-alpine` (matches `.ruby-version` pin).
- No host-side Ruby install. Everything ruby/rails runs via
  `docker run` / `docker compose`.
- Also noted: sudo requires a password on this VM, so any apt-based path
  would have needed user paste.

### Dockerfile + compose fixes to get the boilerplate booting
Three small mismatches in the archived boilerplate had to be fixed:
- Dockerfile pinned `ruby:2.7.2-alpine`, but `Gemfile.lock` / `.ruby-version`
  wants 2.7.4 → bumped Dockerfile to `ruby:2.7.4-alpine`.
- Dockerfile installed `bundler:2.1.4`, but `Gemfile.lock` `BUNDLED WITH`
  is 2.2.24 → bumped to 2.2.24.
- `package.json` pinned `"node": "12.x"` but the alpine image ships
  Node 14 → loosened to `">=12"`.
- `docker-compose.yml` pointed at `dfedigital/govuk-rails-boilerplate:latest`
  on Docker Hub (repo archived, pull denied) → switched to `build: .` +
  local image tag `incident-response-tool:local`.

### Bundle install + compose up
- `docker build --target builder` → bundle install succeeded (22
  Gemfile deps, 54 gems), yarn install + assets:precompile clean.
- `docker build -t incident-response-tool:local .` → full production
  image tagged.
- `docker compose up -d` → Postgres 11 + the web container up. Rails
  6.1.4 booted on Ruby 2.7.4, Puma listening on 0.0.0.0:3000, DB
  created and migrated.
- `curl http://localhost:3000/` returns a 404 (no routes defined yet —
  expected for boilerplate) but the GOV.UK template renders, assets
  load. **Foundations step green.**
- External URL for browser test: `https://3000-lab8103.labs.decoded.com`.

### Read the three individual-scoping docs
- Read all three docs in
  `~/Documents/readwrite-classroom/breakout-collaborations/wk12/dfe-collab/`:
  - `w12-individual-scoping-filled (1).docx` — mine, policy-colleague-in-a-box
  - `w12-individual-scoping-incident-copilot.docx` — mine, on-call runbook copilot
  - `w12-individual-scoping-serena.docx` — Serena, GHBfS logging + runbooks
- Produced short summaries of each and flagged that all three share a
  retrieval + citation + refusal spine.

### Decided team direction
- **Leaning into Serena's file** as the concrete anchor — Get Help Buying
  for Schools is a real DfE service and her domain knowledge grounds the
  demo in something judges recognise.
- Serena's doc is the thinnest of the three (no quantified impact, no
  measurable success statement, risks blank, components half-marked).
  Team will need to tighten scope on day 0.

### Wrote the blended team idea
- File: `team-idea-blended.md`.
- Core architectural choice for the 2-day sprint: **skip the vector DB**.
  Corpus (~15 runbooks, ~30–50k tokens) is small enough to context-stuff
  into Claude with prompt caching. Deletes ~1 day of infra work. Named
  explicitly in the doc as a deliberate choice, not a shortcut.
- Three pillars:
  1. Mock GHBfS service (feeds the demo — chaos endpoint injects seeded
     failures).
  2. Runbook copilot (Claude call with cached corpus, structured output
     forcing citation-or-refusal).
  3. Post-incident runbook drafter (timeline in → Markdown PR out).
- Day 1 = spine end-to-end. Day 2 = drafter + eval + demo polish.

### Cloned the DfE incident-response-tool repo
- `git clone https://github.com/DFE-Digital/incident-response-tool.git`
  into `~/Documents/my-work/w12-hackathon/incident-response-tool/`.
- Already a git repo (`master`, clean tree, single "Initial commit").
- Ruby/Rails stack (Gemfile, Rakefile, config.ru) with a Dockerfile.
- Later switched onto branch `david/documents` (tracked by origin).

### Open questions / next up
- Commit these Step-0 fixes + docs to `david/documents` before doing
  anything else, so we're never one accidental click away from losing
  the work again.
- Rebuild the local image and `docker compose up -d` again to verify
  the app still boots.
- Then Step 1: incident intake form + `Incident` model.
