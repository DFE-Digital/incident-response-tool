require "net/http"
require "json"

# Posts incident + artefact updates to a Teams channel via a Power Automate
# Workflow webhook (the modern replacement for the deprecated Incoming
# Webhook connector).
#
# Each service has its own webhook URL in an env var. If a webhook is not
# configured for the incident's service, or the POST fails, we log and
# continue — never break the artefact flow because comms failed.
#
# The payload is a standard Teams "attachments -> Adaptive Card" shape.
# In Power Automate, wire an "HTTP request" trigger to a "Post adaptive
# card in a chat or channel" action for the target channel.
class TeamsNotifier
  WEBHOOK_ENV_VAR_BY_SERVICE = {
    "Get Help Buying for Schools"     => "TEAMS_WEBHOOK_GHBFS",
    "Child Development Training"      => "TEAMS_WEBHOOK_EYCDT",
    "Help for Early Years Providers"  => "TEAMS_WEBHOOK_HEYP"
  }.freeze

  SEVERITY_COLORS = {
    "P1" => "attention",  # red
    "P2" => "warning",    # orange
    "P3" => "accent",     # blue
    "P4" => "good"        # green
  }.freeze

  def self.incident_opened(incident)
    post(incident, build_opened_card(incident))
  end

  def self.process_generated(incident, artefact)
    post(incident, build_process_card(incident, artefact))
  end

  def self.runbook_generated(incident, artefact)
    post(incident, build_runbook_card(incident, artefact))
  end

  def self.review_generated(incident, artefact)
    post(incident, build_review_card(incident, artefact))
  end

  def self.webhook_for(service)
    env_var = WEBHOOK_ENV_VAR_BY_SERVICE[service]
    return nil unless env_var
    ENV[env_var].presence
  end

  def self.post(incident, card)
    webhook = webhook_for(incident.service)
    unless webhook
      Rails.logger.info("[TeamsNotifier] no webhook configured for service=#{incident.service.inspect}, skipping")
      return
    end

    body = {
      type: "message",
      attachments: [{
        contentType: "application/vnd.microsoft.card.adaptive",
        contentUrl: nil,
        content: card
      }]
    }

    uri = URI(webhook)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("[TeamsNotifier] webhook returned #{response.code}: #{response.body[0..200]}")
    end
  rescue StandardError => e
    Rails.logger.warn("[TeamsNotifier] post failed: #{e.class}: #{e.message}")
  end

  # ------------------------------------------------------------------
  # Card builders
  # ------------------------------------------------------------------

  def self.build_opened_card(incident)
    adaptive_card(
      body: [
        text_block("🚨  Incident ##{incident.id} opened", size: "Large", weight: "Bolder"),
        text_block(incident.title, size: "Medium", weight: "Bolder", wrap: true),
        fact_set([
          { title: "Service", value: incident.service },
          { title: "Status",  value: incident.status.capitalize }
        ]),
        text_block(truncate(incident.description, 500), wrap: true, spacing: "Medium")
      ],
      actions: [view_incident_action(incident)]
    )
  end

  def self.build_process_card(incident, artefact)
    severity_style = SEVERITY_COLORS.fetch(artefact.severity_guess, "default")

    body = [
      text_block("🔧  Process for Incident ##{incident.id}", size: "Medium", weight: "Bolder"),
      container([
        text_block("Severity: #{artefact.severity_guess}", weight: "Bolder", color: severity_style),
        text_block(artefact.severity_reasoning, isSubtle: true, wrap: true)
      ], style: severity_style),
      text_block("Immediate actions", weight: "Bolder", spacing: "Medium"),
      *artefact.immediate_actions.first(4).map { |a| text_block("• #{a}", wrap: true) }
    ]

    body << text_block("Escalation: #{artefact.escalation_path.join(" → ")}",
                       isSubtle: true, wrap: true, spacing: "Medium")

    adaptive_card(body: body, actions: [view_incident_action(incident)])
  end

  def self.build_runbook_card(incident, artefact)
    match_emoji = { "retrieved" => "✅", "drafted" => "✏️", "refused" => "🚫" }.fetch(artefact.match_type, "📖")

    body = [
      text_block("#{match_emoji}  Runbook for Incident ##{incident.id} — #{artefact.match_type.capitalize}",
                 size: "Medium", weight: "Bolder", wrap: true)
    ]

    if artefact.refused?
      body << text_block(artefact.refusal_reason, wrap: true)
      body << fact_set([{ title: "Escalate to", value: artefact.owner_to_escalate_to }])
    else
      source =
        if artefact.runbook_id.present?
          section = artefact.cited_section.present? ? " — #{artefact.cited_section}" : ""
          "#{artefact.runbook_id}#{section}"
        else
          "Drafted from scratch (no similar runbook)"
        end

      body << fact_set([
        { title: "Source",      value: source },
        { title: "Escalate to", value: artefact.owner_to_escalate_to }
      ])

      if artefact.steps.any?
        body << text_block("Steps", weight: "Bolder", spacing: "Medium")
        artefact.steps.first(4).each_with_index do |step, i|
          body << text_block("#{i + 1}. #{step["action"]}", wrap: true)
        end
        if artefact.steps.length > 4
          body << text_block("…and #{artefact.steps.length - 4} more step(s) in the incident page.",
                             isSubtle: true, wrap: true)
        end
      end
    end

    adaptive_card(body: body, actions: [view_incident_action(incident)])
  end

  def self.build_review_card(incident, artefact)
    body = [
      text_block("✅  Incident ##{incident.id} resolved — review ready",
                 size: "Medium", weight: "Bolder"),
      text_block("Ready for the retrospective. Root cause and the reflective questions are blank — fill them in as a team during the meeting.",
                 isSubtle: true, wrap: true),
      fact_set([
        { title: "User impact",   value: artefact.user_impact.to_s },
        { title: "End time",      value: artefact.end_datetime.strftime("%-d %B %Y at %H:%M") },
        { title: "Technical lead", value: artefact.technical_lead.presence || "(not recorded)" },
        { title: "Comms lead",     value: artefact.comms_lead.presence || "(not recorded)" },
        { title: "Support lead",   value: artefact.support_lead.presence || "(not recorded)" }
      ])
    ]

    if artefact.timeline.any?
      body << text_block("Timeline (#{artefact.timeline.length} events)", weight: "Bolder", spacing: "Medium")
      artefact.timeline.first(6).each do |row|
        body << text_block("#{row["time"]}: #{row["event"]}", wrap: true)
      end
    end

    actions = [
      view_incident_action(incident),
      {
        type: "Action.OpenUrl",
        title: "Download review (.docx)",
        url: url_for("/incidents/#{incident.id}/review_artefact/download")
      }
    ]

    adaptive_card(body: body, actions: actions)
  end

  # ------------------------------------------------------------------
  # Small builders
  # ------------------------------------------------------------------

  def self.adaptive_card(body:, actions: [])
    {
      "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
      type: "AdaptiveCard",
      version: "1.4",
      body: body,
      actions: actions
    }
  end

  def self.text_block(text, **opts)
    { type: "TextBlock", text: text.to_s }.merge(opts)
  end

  def self.fact_set(facts)
    { type: "FactSet", facts: facts }
  end

  def self.container(items, style: nil)
    c = { type: "Container", items: items }
    c[:style] = style if style
    c
  end

  def self.view_incident_action(incident)
    { type: "Action.OpenUrl", title: "View incident", url: url_for("/incidents/#{incident.id}") }
  end

  def self.url_for(path)
    "#{ENV.fetch("APP_BASE_URL", "http://localhost:3000")}#{path}"
  end

  def self.truncate(text, limit)
    return text if text.to_s.length <= limit
    text.to_s[0, limit].rstrip + "…"
  end
end
