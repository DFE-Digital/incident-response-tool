# Incident Response Tool

A Claude-powered runbook copilot for UK Government digital services. Submit an incident in plain text and get back a structured response process, a grounded runbook, and — once resolved — a post-incident review draft. Built on GOV.UK Design System Rails.

## Prerequisites

- Docker (or Podman with the `docker` shim — both work)
- An Anthropic API key (`ANTHROPIC_API_KEY`)

No local Ruby, Node, or PostgreSQL installation required.

## Quick start (development)

```bash
# 1. Build the image (first time, or after Gemfile/package.json changes)
make build

# 2. Export your API key
export ANTHROPIC_API_KEY=sk-ant-...

# 3. Start the dev environment (live source mount, auto-reload)
make dev
```

The app is available at **http://localhost:3000** (or via your lab proxy at `https://3000-<hostname>/`).

On first run, `db:create` and `db:migrate` run automatically before the server starts. Subsequent starts skip the wait and boot in ~5 s.

### Stopping

```bash
make dev-down
```

## Makefile targets

| Target | Description |
|---|---|
| `make build` | Build the Docker image (uses layer cache — fast for code-only changes) |
| `make rebuild` | Full rebuild without cache (use when Gemfile or package.json change) |
| `make dev` | Start dev environment with live source mount |
| `make dev-down` | Stop and remove dev containers |
| `make up` | Start in production mode (baked image, no source mount) |
| `make down` | Stop production containers |
| `make logs` | Tail web container logs |

## Environment variables

| Variable | Required | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | Yes | Anthropic API key for Claude calls |
| `RAILS_ENV` | No | Defaults to `development` in dev compose |
| `DATABASE_URL` | No | Set automatically by dev compose |
| `SECRET_KEY_BASE` | No | Set to a placeholder in dev compose |

In development the API key is passed through from your shell:

```bash
export ANTHROPIC_API_KEY=sk-ant-...
make dev
```

## Architecture

- **Rails 6.1** on Ruby 2.7.4 (Alpine Docker)
- **GOV.UK Design System** — govuk-frontend 3.12, govuk-components, govuk_design_system_formbuilder
- **PostgreSQL 11** via Docker service
- **Claude API** — plain `Net::HTTP` calls (no SDK dependency), structured JSON output
- Assets precompiled into the image via Webpacker; served as static files in both dev and production modes

## Running database migrations

Migrations run automatically on container start. To run them manually:

```bash
docker exec incident-response-tool_web_1 bundle exec rails db:migrate
```

## Stack

- Ruby 2.7.4
- Rails 6.1.4
- PostgreSQL 11
- Webpacker 5 / govuk-frontend 3.12
