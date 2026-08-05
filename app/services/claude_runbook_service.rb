require "net/http"
require "json"

class ClaudeRunbookService
  API_URL = URI("https://api.anthropic.com/v1/messages").freeze
  MODEL   = "claude-opus-4-7".freeze

  INSTRUCTIONS = <<~PROMPT.freeze
    You are an incident-response assistant for the DfE Get Help Buying for
    Schools (GHBfS) service. You have access to a corpus of runbooks below.

    When given an incident description, you decide one of three things:

    1. **retrieved** — the incident clearly matches one runbook in the
       corpus. Return that runbook's steps, cite the runbook_id and the
       most-relevant section heading, and name the owner to escalate to
       if the runbook doesn't resolve.

    2. **drafted** — the incident is similar to something in the corpus
       but no runbook is an exact match. Draft a short runbook stub
       modelled on the closest existing pattern, and name the owner to
       escalate to. Set runbook_id to the closest existing match.

    3. **refused** — the incident is outside the scope of the corpus
       (e.g. HR issue, physical building issue, an entirely different
       service). Do not draft a runbook. Explain briefly in
       refusal_reason and name the owner to escalate to.

    Return a single JSON object matching this exact schema — no prose,
    no markdown fences:

    {
      "match_type": "retrieved" | "drafted" | "refused",
      "runbook_id": "<id from corpus>" | null,
      "cited_section": "<section heading from that runbook>" | null,
      "general_guidance": "<one paragraph, drafted case only>" | null,
      "steps": [
        {
          "action": "<verb-phrased heading>",
          "commands": ["<exact command or endpoint>"],
          "verification": "<how to confirm this step worked>"
        }
      ],
      "owner_to_escalate_to": "<@team-handle>",
      "refusal_reason": "<one sentence, refused case only>" | null
    }

    Rules:
    - For refused, steps must be an empty array [].
    - Owner must always be a team handle starting with @, never a person's name.
    - Do not invent runbook_ids that are not in the corpus.
    - Prefer refusal over invention when uncertain.
  PROMPT

  def initialize(incident)
    @incident = incident
  end

  def call
    body = {
      model: MODEL,
      max_tokens: 2048,
      system: [
        { type: "text", text: INSTRUCTIONS },
        {
          type: "text",
          text: RunbookCorpus.formatted_for_prompt,
          cache_control: { type: "ephemeral" }
        }
      ],
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

    RunbookArtefact.create!(
      incident: @incident,
      match_type: json.fetch("match_type"),
      runbook_id: json["runbook_id"],
      cited_section: json["cited_section"],
      general_guidance: json["general_guidance"],
      steps: json.fetch("steps"),
      owner_to_escalate_to: json.fetch("owner_to_escalate_to"),
      refusal_reason: json["refusal_reason"]
    )
  end
end
