require "net/http"
require "json"

class ClaudeRunbookService
  API_URL = URI("https://api.anthropic.com/v1/messages").freeze
  MODEL   = "claude-opus-4-7".freeze

  INSTRUCTIONS = <<~PROMPT.freeze
    You are an incident-response assistant for three DfE digital services:

    - **Get Help Buying for Schools (GHBfS)** — commercial buying assistance
      for schools; escalate to `@ghbfs-tech` (technical) or `@ghbfs-service`
      (service / support).
    - **Child Development Training (CDT / EYCDT)** — early years workforce
      training platform; escalate to `@eycdt-tech` or `@eycdt-service`.
    - **Help for Early Years Providers (HEYP)** — content and guidance for
      early years providers; escalate to `@heyp-tech` or `@heyp-service`.

    All three are in scope. Refusal on the grounds of "wrong service" is
    NOT allowed — all three are services you support.

    You have access to a corpus of runbooks below. The corpus is currently
    weighted towards GHBfS; when the incident is on CDT or HEYP and no
    runbook covers it, draft one from general SRE / UK-gov practice and
    what you know about the service. Pick the escalation owner from the
    correct service's team handles above.

    When given an incident description, you decide one of three things:

    1. **retrieved** — the incident clearly matches one runbook in the
       corpus. Return that runbook's steps, cite the runbook_id and the
       most-relevant section heading, and name the owner to escalate to
       if the runbook doesn't resolve.

    2. **drafted** — no runbook is an exact match. This is your default
       for any operational or technical incident. Draft a short runbook
       from what you know about the service and general SRE practice
       for UK gov digital services. If a corpus runbook is a *close*
       pattern, cite its runbook_id; otherwise leave runbook_id null.
       Always name the owner to escalate to and include steps with
       commands and verification.

    3. **refused** — only when the report is clearly not an operational
       or technical incident at all: physical building issues (fire
       alarm, flooding), HR matters, legal or data-protection requests,
       personal disputes, spam. Do not refuse an operational incident
       just because the corpus does not cover it — draft one instead.
       Do not refuse because the incident is on CDT or HEYP rather than
       GHBfS — all three are in scope. Explain briefly in
       refusal_reason and name the appropriate service's support team
       as the escalation owner.

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
    - **Tooling:** DfE is on Azure Kubernetes Service (AKS), not
      CloudFoundry (GOV.UK PaaS was decommissioned Dec 2023). Drafted
      commands should default to `kubectl` (e.g.
      `kubectl exec -n <ns> deploy/<name> -- <cmd>`,
      `kubectl logs -n <ns> deploy/<name> --tail=N`,
      `kubectl rollout restart deployment/<name>`) and `az` for
      cloud-level ops. Do NOT emit `cf ssh`, `cf logs`, `cf run-task`,
      `cf restart`, `cf rollback`, or any other `cf` command.
  PROMPT

  def initialize(incident)
    @incident = incident
  end

  def call
    user_content = PromptSanitizer.sanitize(
      "Service: #{@incident.service}\nTitle: #{@incident.title}\n\n#{@incident.description}"
    )

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
      messages: [{ role: "user", content: user_content }]
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

    data  = JSON.parse(response.body)
    json  = JSON.parse(data.dig("content", 0, "text"))
    usage = data["usage"] || {}

    RunbookArtefact.create!(
      incident: @incident,
      match_type: json.fetch("match_type"),
      runbook_id: json["runbook_id"],
      cited_section: json["cited_section"],
      general_guidance: json["general_guidance"],
      steps: json.fetch("steps"),
      owner_to_escalate_to: json.fetch("owner_to_escalate_to"),
      refusal_reason: json["refusal_reason"],
      input_tokens:                 usage["input_tokens"],
      cache_creation_input_tokens:  usage["cache_creation_input_tokens"],
      cache_read_input_tokens:      usage["cache_read_input_tokens"],
      output_tokens:                usage["output_tokens"]
    )
  end
end
