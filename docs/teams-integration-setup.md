# Setting up Teams integration for local testing

Two testing paths, easiest first.

The notifier lives in `app/services/teams_notifier.rb`. It POSTs an
Adaptive Card to a per-service webhook URL. If a webhook is not set,
it logs and skips — the artefact flow never fails because of Teams.

## Option A — webhook.site (5 minutes, no Teams needed)

Fastest way to see the payloads Rails would send. You get a public URL
that captures POSTs and shows the JSON.

1. Go to <https://webhook.site> in your browser. A unique URL is
   generated for you.
2. Copy the "Your unique URL" — that's your fake webhook.
3. Export it in the shell where you run `make dev`, along with
   `APP_BASE_URL` so the card's "View incident" / "Download review"
   buttons link to somewhere real:
   ```sh
   export TEAMS_WEBHOOK_GHBFS=https://webhook.site/<your-uuid>
   export APP_BASE_URL=https://3000-<lab-hostname>.labs.decoded.com
   ```
4. Restart the dev compose so the env reaches the container:
   ```sh
   make dev-down && make dev
   ```
5. Create a GHBfS incident in the browser. Every artefact you
   generate posts a fresh Adaptive Card to webhook.site — the page
   updates live.

You can point `TEAMS_WEBHOOK_EYCDT` and `TEAMS_WEBHOOK_HEYP` at the
same webhook.site URL to see cards for all three services.

## Option B — a real Teams channel via Power Automate

This gets you an actual Adaptive Card in a Teams channel.

**Classic Incoming Webhooks are being retired in 2025 — don't use
those. Use a Workflow.**

Easiest route, from inside Teams:

1. Teams → the channel you want notifications in → ⋯ → **Workflows**.
2. Search "webhook" → **Post to a channel when a webhook request is
   received**.
3. Follow the wizard. Sign in when prompted, choose the team + channel,
   click **Create flow**.
4. Copy the URL it displays — that's your webhook. Save it somewhere
   safe; you can't get it back easily after closing the dialog.
5. Set it in your shell:
   ```sh
   export TEAMS_WEBHOOK_GHBFS=https://prod-xx.uksouth.logic.azure.com:443/...
   make dev-down && make dev
   ```

Longer route via <https://make.powerautomate.com> if the in-Teams
wizard isn't available in your tenant:

1. **Create → Instant cloud flow**.
2. Trigger: **When a HTTP request is received**. Leave the schema
   blank for now (the trigger accepts any JSON).
3. Add step: **Post adaptive card in a chat or channel** (from the
   Microsoft Teams connector).
4. Set the "Adaptive Card" field to the expression
   `triggerBody()?['attachments']?[0]?['content']` — this pulls our
   card out of the payload we POST.
5. Save the flow. The HTTP URL becomes available in the trigger step
   after the first save — copy it into the env var above.

## What each event looks like

Once the webhook is wired up:

| Trigger | Card contents |
|---|---|
| Submit "Report an incident" form | 🚨 title, service, description preview. **View incident** button. |
| Click "Generate process" | 🔧 severity chip (P1 red → P4 green), reasoning, first 4 immediate actions, escalation chain. **View incident** button. |
| Click "Find runbook" | 📖 match type (retrieved / drafted / refused) as an emoji + label, source citation (runbook id + section, or "Drafted from scratch"), first 4 step titles. **View incident** button. |
| Click "Mark resolved" and submit the form | ✅ user impact, end time, three leads, first 6 timeline entries. **View incident** + **Download review (.docx)** buttons. |

Every card includes the incident ID in its title, so successive cards
for the same incident visually group in the channel even without true
threading. Real threading needs Graph API + OAuth (see plan.md Step 5,
"future work").

## Debugging

Watch the Rails logs while you trigger events:
```sh
docker logs -f incident-response-tool_web_1 | grep TeamsNotifier
```

Expected log lines:

- `[TeamsNotifier] no webhook configured for service=..., skipping`
  → env var isn't set for that service. Check with:
  ```sh
  docker exec incident-response-tool_web_1 env | grep -E "TEAMS_|APP_BASE"
  ```
  If they're missing, the container didn't pick them up — restart with
  `make dev-down && make dev` after exporting.
- `[TeamsNotifier] webhook returned 4xx/5xx: ...` → the webhook is
  wired up but rejected the POST. Check the response body preview in
  the log; common causes: expired flow, Workflow expecting a different
  payload shape.
- `[TeamsNotifier] post failed: ...` → network error reaching the
  webhook host. Check DNS / firewall.

**The notifier never raises.** If Teams is broken, the artefact still
saves and the UI still works — you'll just miss the notification.

## Env var reference

| Var | Purpose | Example |
|---|---|---|
| `TEAMS_WEBHOOK_GHBFS` | Webhook for Get Help Buying for Schools | `https://webhook.site/abc…` or `https://prod-xx.uksouth.logic.azure.com:443/…` |
| `TEAMS_WEBHOOK_EYCDT` | Webhook for Child Development Training | (same shape) |
| `TEAMS_WEBHOOK_HEYP` | Webhook for Help for Early Years Providers | (same shape) |
| `APP_BASE_URL` | Base URL used in the card action buttons | `https://3000-code-lab8103.labs.decoded.com` — defaults to `http://localhost:3000` if unset, which won't work from Teams |

Incidents with `service: "Other"` don't map to a webhook and are
always skipped. That's intentional — the fourth option is a
catch-all, not a real service with a team channel.

## Testing the notifier in isolation

If you want to verify a card renders correctly without going through
the UI, use `rails runner`:

```sh
docker exec incident-response-tool_web_1 bundle exec rails runner "
  i = Incident.last
  card = TeamsNotifier.build_process_card(i, i.process_artefact)
  puts JSON.pretty_generate(card)
"
```

Or send a real POST to your configured webhook:

```sh
docker exec incident-response-tool_web_1 bundle exec rails runner "
  i = Incident.last
  TeamsNotifier.incident_opened(i)
"
```

Both are safe to run repeatedly.
