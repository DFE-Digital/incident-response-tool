class ProcessArtefactsController < ApplicationController
  def create
    @incident = Incident.find(params[:incident_id])

    if @incident.process_artefact.present?
      redirect_to @incident, notice: "Process artefact already generated."
      return
    end

    ClaudeProcessService.new(@incident).call
    redirect_to @incident
  rescue JSON::ParserError
    redirect_to @incident, alert: "Claude returned an unexpected response — please try again."
  rescue KeyError => e
    redirect_to @incident, alert: "Response was missing a required field (#{e.message}) — please try again."
  end

  def download
    incident = Incident.find(params[:incident_id])
    artefact = incident.process_artefact
    if artefact.blank?
      redirect_to incident, alert: "No process to download yet — generate next steps first."
      return
    end

    send_data Htmltoword::Document.create(build_doc(incident, artefact)),
              filename: "incident-#{incident.id}-process.docx",
              type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
              disposition: "attachment"
  end

  private

  # Uses htmltoword to convert this HTML into a real .docx (OOXML).
  # Word, Google Docs and LibreOffice all open it as a native document.
  def build_doc(incident, artefact)
    h = ->(s) { ERB::Util.html_escape(s.to_s) }
    ul = ->(items) { "<ul>" + items.map { |i| "<li>#{h.call(i)}</li>" }.join + "</ul>" }
    ol = ->(items) { "<ol>" + items.map { |i| "<li>#{h.call(i)}</li>" }.join + "</ol>" }
    description_html = h.call(incident.description).gsub(/\r?\n/, "<br>")

    <<~HTML
      <!DOCTYPE html>
      <html xmlns:o="urn:schemas-microsoft-com:office:office"
            xmlns:w="urn:schemas-microsoft-com:office:word"
            xmlns="http://www.w3.org/TR/REC-html40">
      <head>
        <meta charset="utf-8">
        <title>Incident ##{incident.id} — #{h.call(incident.title)}</title>
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

        <h2>Incident response process</h2>
        <p><strong>Severity: #{h.call(artefact.severity_guess)}</strong> — #{h.call(artefact.severity_reasoning)}</p>

        <h3>Immediate actions</h3>
        #{ul.call(artefact.immediate_actions)}

        <h3>Communication actions</h3>
        #{ul.call(artefact.communication_actions)}

        <h3>Escalation path</h3>
        #{ol.call(artefact.escalation_path)}
      </body>
      </html>
    HTML
  end
end
