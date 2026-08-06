class RunbookArtefactsController < ApplicationController
  def create
    @incident = Incident.find(params[:incident_id])

    if @incident.runbook_artefact.present?
      redirect_to @incident, notice: "Runbook artefact already generated."
      return
    end

    artefact = ClaudeRunbookService.new(@incident).call
    TeamsNotifier.runbook_generated(@incident, artefact)
    redirect_to @incident
  rescue JSON::ParserError
    redirect_to @incident, alert: "Claude returned an unexpected response — please try again."
  rescue KeyError => e
    redirect_to @incident, alert: "Response was missing a required field (#{e.message}) — please try again."
  end

  def download
    incident = Incident.find(params[:incident_id])
    artefact = incident.runbook_artefact
    if artefact.blank?
      redirect_to incident, alert: "No runbook to download yet — find one first."
      return
    end

    send_data Htmltoword::Document.create(build_doc(incident, artefact)),
              filename: "incident-#{incident.id}-runbook.docx",
              type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
              disposition: "attachment"
  end

  private

  # Uses htmltoword to convert this HTML into a real .docx (OOXML).
  # Word, Google Docs and LibreOffice all open it as a native document.
  def build_doc(incident, artefact)
    h = ->(s) { ERB::Util.html_escape(s.to_s) }
    description_html = h.call(incident.description).gsub(/\r?\n/, "<br>")

    body =
      if artefact.refused?
        <<~HTML
          <h2>Runbook</h2>
          <p><strong>Refused — no runbook covers this incident.</strong></p>
          <p>#{h.call(artefact.refusal_reason)}</p>
          <p><strong>Escalate to:</strong> #{h.call(artefact.owner_to_escalate_to)}</p>
        HTML
      else
        source =
          if artefact.runbook_id.present?
            citation = "<code>#{h.call(artefact.runbook_id)}</code>"
            citation += " — #{h.call(artefact.cited_section)}" if artefact.cited_section.present?
            citation += " (drafted from this close match)" if artefact.drafted?
            citation
          else
            "Drafted from scratch — no similar runbook in the corpus"
          end

        guidance =
          if artefact.drafted? && artefact.general_guidance.present?
            "<blockquote>#{h.call(artefact.general_guidance)}</blockquote>"
          else
            ""
          end

        steps_html = artefact.steps.map do |step|
          cmds = Array(step["commands"]).map { |c| "<pre>#{h.call(c)}</pre>" }.join
          verify = step["verification"].present? ? "<p><em>Verify:</em> #{h.call(step["verification"])}</p>" : ""
          "<li><strong>#{h.call(step["action"])}</strong>#{cmds}#{verify}</li>"
        end.join

        <<~HTML
          <h2>Runbook (#{h.call(artefact.match_type)})</h2>
          <p><strong>Source:</strong> #{source}</p>
          <p><strong>Escalate to:</strong> #{h.call(artefact.owner_to_escalate_to)}</p>
          #{guidance}
          <h3>Steps</h3>
          <ol>#{steps_html}</ol>
        HTML
      end

    <<~HTML
      <!DOCTYPE html>
      <html xmlns:o="urn:schemas-microsoft-com:office:office"
            xmlns:w="urn:schemas-microsoft-com:office:word"
            xmlns="http://www.w3.org/TR/REC-html40">
      <head>
        <meta charset="utf-8">
        <title>Incident ##{incident.id} — #{h.call(incident.title)} — Runbook</title>
      </head>
      <body>
        <h1>Incident ##{incident.id}: #{h.call(incident.title)}</h1>
        <p>
          <strong>Service:</strong> #{h.call(incident.service)}<br>
          <strong>Status:</strong> #{h.call(incident.status.capitalize)}<br>
          <strong>Reported:</strong> #{h.call(incident.created_at.strftime("%-d %B %Y at %H:%M"))}
        </p>

        <h2>What happened</h2>
        <p>#{description_html}</p>

        <hr>

        #{body}
      </body>
      </html>
    HTML
  end
end
