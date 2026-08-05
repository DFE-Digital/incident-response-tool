require "net/http"
require "json"

class ClaudeProcessService
  API_URL = URI("https://api.anthropic.com/v1/messages").freeze
  MODEL   = "claude-opus-4-7".freeze

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are an incident-response coach for UK Government digital services.
    When given an incident description you return a structured JSON object only — no prose, no markdown fences.

    The JSON must match exactly:
    {
      "severity_guess": "P1" | "P2" | "P3" | "P4",
      "severity_reasoning": "<one sentence>",
      "immediate_actions": ["<action>", ...],
      "communication_actions": ["<action>", ...],
      "escalation_path": ["<role>", ...]
    }

    Severity guide:
      P1 — complete service outage or data breach, all users affected.
      P2 — major degradation, significant portion of users affected or at risk.
      P3 — partial degradation, workaround exists, limited users affected.
      P4 — minor issue, cosmetic or single-user, no service risk.

    immediate_actions: triage and containment steps, 3–6 items.
    communication_actions: who to notify and when (service owner, users, comms lead), 2–4 items.
    escalation_path: ordered list of named *roles* (not people), 2–4 items.

    Return only the JSON object.
  PROMPT

  def initialize(incident)
    @incident = incident
  end

  def call
    body = {
      model: MODEL,
      max_tokens: 1024,
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: "Service: #{@incident.service}\nTitle: #{@incident.title}\n\n#{@incident.description}"
        }
      ]
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

    ProcessArtefact.create!(
      incident: @incident,
      severity_guess: json.fetch("severity_guess"),
      severity_reasoning: json.fetch("severity_reasoning"),
      immediate_actions: json.fetch("immediate_actions"),
      communication_actions: json.fetch("communication_actions"),
      escalation_path: json.fetch("escalation_path")
    )
  end
end
