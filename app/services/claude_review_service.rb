require "net/http"
require "json"

class ClaudeReviewService
  API_URL = URI("https://api.anthropic.com/v1/messages").freeze
  MODEL   = "claude-opus-4-7".freeze

  INSTRUCTIONS = <<~PROMPT.freeze
    You are drafting a post-incident review in the exact shape of DfE's
    incident-report template. The reader is a DfE Digital delivery team
    who will paste this into their Word doc and edit it in the
    retrospective meeting.

    Voice: **blameless**. Hold to the retrospective prime directive spirit:
    "Regardless of what we discover, we understand and truly believe that
    everyone did the best job they could, given what they knew at the
    time, their skills and abilities, the resources available, and the
    situation at hand." Do not blame individuals. Focus on the system,
    the process, the tools, and the information available at the time.
    Do not use catastrophising language.

    Return one JSON object matching this schema — no prose, no markdown
    fences:

    {
      "user_impact": "<1-2 sentences. Voice: 'Users were unable to X and Y could not Z.'>",
      "root_cause": "<1-2 sentences>",
      "timeline": [
        { "time": "<HH:MM or T+Nm>", "event": "<one line>" }
      ],
      "alerted_quickly": "<1 paragraph — were we alerted quickly?>",
      "diagnosed_and_fixed_quickly": "<1 paragraph — were we able to diagnose and fix the immediate issue quickly?>",
      "how_we_solved_it": "<1 paragraph>",
      "process_and_comms": "<1 paragraph — was the process followed well, were comms effective?>",
      "prevent_recurrence": ["<action>", ...],
      "improve_response": ["<action>", ...],
      "improve_process_comms": ["<action>", ...],
      "runbook_diff": "<Markdown, see below>"
    }

    Rules:
    - Timeline: preserve any times the user provided; otherwise use T+0,
      T+5m style relative markers. Time-ordered.
    - Each bulleted array: 2-4 items, action-oriented, concrete.
    - runbook_diff:
      - If a runbook was retrieved for this incident, produce a Markdown
        diff (```diff fenced block with + and - lines) improving it.
      - If a runbook was drafted for this incident, produce a Markdown
        block containing a runbook stub in the corpus shape (frontmatter
        with runbook_id/owner/last_updated + section headings) so the
        team can commit it.
      - If no runbook was matched or drafted, return an empty string.
    - Escalation and role vocabulary should match the DfE playbook
      (comms lead / tech lead / support lead / delivery manager /
      service owner).
    - Do NOT emit any CloudFoundry commands (`cf ssh`, `cf logs`,
      `cf run-task`, `cf restart` etc.). DfE is on Azure Kubernetes
      Service. Default to `kubectl` and `az` in any runbook_diff.
  PROMPT

  def initialize(incident, review)
    @incident = incident
    @review   = review
  end

  def call
    body = {
      model: MODEL,
      max_tokens: 4096,
      system: INSTRUCTIONS,
      messages: [{ role: "user", content: user_message }]
    }

    http = Net::HTTP.new(API_URL.host, API_URL.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(API_URL.path)
    request["Content-Type"]      = "application/json"
    request["x-api-key"]         = ENV.fetch("ANTHROPIC_API_KEY")
    request["anthropic-version"] = "2023-06-01"
    request.body = body.to_json

    response = http.request(request)
    raise "Claude API error #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    json = JSON.parse(data.dig("content", 0, "text"))

    @review.update!(
      user_impact:                 json.fetch("user_impact"),
      root_cause:                  json.fetch("root_cause"),
      timeline:                    json.fetch("timeline"),
      alerted_quickly:             json.fetch("alerted_quickly"),
      diagnosed_and_fixed_quickly: json.fetch("diagnosed_and_fixed_quickly"),
      how_we_solved_it:            json.fetch("how_we_solved_it"),
      process_and_comms:           json.fetch("process_and_comms"),
      prevent_recurrence:          json.fetch("prevent_recurrence"),
      improve_response:            json.fetch("improve_response"),
      improve_process_comms:       json.fetch("improve_process_comms"),
      runbook_diff:                json["runbook_diff"].to_s
    )
  end

  private

  def user_message
    process = @incident.process_artefact
    runbook = @incident.runbook_artefact

    parts = []

    parts << "== Incident =="
    parts << "Service: #{@incident.service}"
    parts << "Title: #{@incident.title}"
    parts << "Reported: #{@incident.created_at.strftime("%-d %B %Y at %H:%M")}"
    parts << "Resolved: #{@review.end_datetime.strftime("%-d %B %Y at %H:%M")}"
    parts << ""
    parts << "Description:"
    parts << @incident.description
    parts << ""

    if process
      parts << "== Process artefact (severity, actions decided at the time) =="
      parts << "Severity: #{process.severity_guess} — #{process.severity_reasoning}"
      parts << "Immediate actions: #{process.immediate_actions.join(" | ")}"
      parts << "Communication actions: #{process.communication_actions.join(" | ")}"
      parts << "Escalation path: #{process.escalation_path.join(" -> ")}"
      parts << ""
    end

    if runbook
      parts << "== Runbook artefact =="
      parts << "Match: #{runbook.match_type}"
      parts << "Runbook ID: #{runbook.runbook_id || '(none)'}"
      parts << "Cited section: #{runbook.cited_section || '(none)'}"
      parts << "Escalate to: #{runbook.owner_to_escalate_to}"
      parts << "Guidance: #{runbook.general_guidance}" if runbook.general_guidance.present?
      unless runbook.steps.empty?
        parts << "Steps followed:"
        runbook.steps.each_with_index do |s, i|
          parts << "  #{i + 1}. #{s["action"]}"
        end
      end
      parts << ""
    end

    parts << "== Roles during the incident =="
    parts << "Technical lead: #{@review.technical_lead.presence || '(not recorded)'}"
    parts << "Comms lead: #{@review.comms_lead.presence || '(not recorded)'}"
    parts << "Support lead: #{@review.support_lead.presence || '(not recorded)'}"
    parts << ""

    if @review.timeline_notes.present?
      parts << "== Timeline notes from the on-caller =="
      parts << @review.timeline_notes
      parts << ""
    end

    if @review.resolution_notes.present?
      parts << "== Resolution notes =="
      parts << @review.resolution_notes
      parts << ""
    end

    parts.join("\n")
  end
end
