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
