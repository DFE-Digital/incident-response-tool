require "net/http"
require "json"

class ClaudeReviewService
  API_URL = URI("https://api.anthropic.com/v1/messages").freeze
  MODEL   = "claude-opus-4-7".freeze

  INSTRUCTIONS = <<~PROMPT.freeze
    You are pre-drafting the factual header of a DfE post-incident
    review — specifically the "User impact" line and the "Timeline"
    table from the DfE Incident Report template.

    Scope: fill in what you know from the incident record so the team
    doesn't have to reconstruct it from memory. Everything after the
    timeline (root cause, the six reflective questions, prevent /
    improve action lists, runbook diff) is for the humans to discuss
    and fill in *during* the retrospective meeting. Do NOT try to
    answer those questions.

    Voice: **blameless**. Hold to the retrospective prime directive
    spirit: "Regardless of what we discover, we understand and truly
    believe that everyone did the best job they could, given what
    they knew at the time, their skills and abilities, the resources
    available, and the situation at hand." Do not blame individuals.
    Do not use catastrophising language.

    Return one JSON object matching this schema — no prose, no
    markdown fences:

    {
      "user_impact": "<1-2 sentences. Voice: 'Users were unable to X and Y could not Z.'>",
      "timeline": [
        { "time": "<HH:MM or T+Nm>", "event": "<one line>" }
      ]
    }

    Rules:
    - Timeline: preserve any times the user provided; otherwise use
      T+0, T+5m style relative markers. Time-ordered. One line per
      event, no editorial commentary.
    - user_impact should describe *what users could not do*, not the
      technical cause.
    - Do not include any other fields in the output.
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
      user_impact: json.fetch("user_impact"),
      timeline:    json.fetch("timeline")
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
