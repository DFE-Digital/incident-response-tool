class ReviewArtefactsController < ApplicationController
  def new
    @incident = Incident.find(params[:incident_id])

    if @incident.review_artefact.present?
      redirect_to @incident, notice: "Post-incident review already generated."
      return
    end

    @review = @incident.build_review_artefact(end_datetime: Time.current)
  end

  def create
    @incident = Incident.find(params[:incident_id])

    if @incident.review_artefact.present?
      redirect_to @incident, notice: "Post-incident review already generated."
      return
    end

    @review = @incident.build_review_artefact(review_params)

    ActiveRecord::Base.transaction do
      @review.save!
      ClaudeReviewService.new(@incident, @review).call
      @incident.update!(status: "resolved")
    end

    TeamsNotifier.review_generated(@incident, @review)
    redirect_to @incident
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  rescue JSON::ParserError
    @review.destroy if @review.persisted?
    redirect_to @incident, alert: "Claude returned an unexpected response — please try again."
  rescue KeyError => e
    @review.destroy if @review.persisted?
    redirect_to @incident, alert: "Response was missing a required field (#{e.message}) — please try again."
  end

  def download
    incident = Incident.find(params[:incident_id])
    artefact = incident.review_artefact
    if artefact.blank?
      redirect_to incident, alert: "No review to download yet — mark the incident resolved first."
      return
    end

    send_data Htmltoword::Document.create(build_doc(incident, artefact)),
              filename: "incident-#{incident.id}-review.docx",
              type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
              disposition: "attachment"
  end

  private

  def review_params
    params.require(:review_artefact).permit(
      :end_datetime, :technical_lead, :comms_lead, :support_lead,
      :timeline_notes, :resolution_notes
    )
  end

  PRIME_DIRECTIVE = <<~QUOTE.freeze
    "Regardless of what we discover, we understand and truly believe that
    everyone did the best job they could, given what they knew at the time,
    their skills and abilities, the resources available, and the situation
    at hand."
  QUOTE

  def build_doc(incident, review)
    h = ->(s) { ERB::Util.html_escape(s.to_s) }
    ul = ->(items) { "<ul>" + Array(items).map { |i| "<li>#{h.call(i)}</li>" }.join + "</ul>" }
    description_html = h.call(incident.description).gsub(/\r?\n/, "<br>")

    timeline_rows = Array(review.timeline).map do |row|
      "<tr><td>#{h.call(row["time"])}</td><td>#{h.call(row["event"])}</td></tr>"
    end.join

    process = incident.process_artefact
    severity_row = process ? "<strong>Priority:</strong> #{h.call(process.severity_guess)}<br>" : ""

    <<~HTML
      <!DOCTYPE html>
      <html xmlns:o="urn:schemas-microsoft-com:office:office"
            xmlns:w="urn:schemas-microsoft-com:office:word"
            xmlns="http://www.w3.org/TR/REC-html40">
      <head>
        <meta charset="utf-8">
        <title>Incident ##{incident.id} — #{h.call(incident.title)} — Review</title>
      </head>
      <body>
        <h1>Incident report ##{incident.id}: #{h.call(incident.title)}</h1>

        <p>
          <strong>Status:</strong> #{h.call(incident.status.capitalize)}<br>
          <strong>Start date &amp; time:</strong> #{h.call(incident.created_at.strftime("%-d %B %Y at %H:%M"))}<br>
          <strong>End date &amp; time:</strong> #{h.call(review.end_datetime.strftime("%-d %B %Y at %H:%M"))}<br>
          <strong>Application / process:</strong> #{h.call(incident.service)}<br>
          #{severity_row}
          <strong>Technical lead:</strong> #{h.call(review.technical_lead.presence || '(not recorded)')}<br>
          <strong>Comms lead:</strong> #{h.call(review.comms_lead.presence || '(not recorded)')}<br>
          <strong>Support lead:</strong> #{h.call(review.support_lead.presence || '(not recorded)')}
        </p>

        <p><strong>User impact:</strong> #{h.call(review.user_impact)}</p>

        <h2>What happened</h2>
        <p>#{description_html}</p>

        <h2>Timeline</h2>
        <table border="1" cellpadding="4" cellspacing="0">
          <tr><th>Time</th><th>Event</th></tr>
          #{timeline_rows}
        </table>

        <h2>Incident Review</h2>
        <blockquote><em>#{h.call(PRIME_DIRECTIVE)}</em></blockquote>

        <p><em>For the retrospective meeting. Fill these in together as
        a team.</em></p>

        <p><strong>Date &amp; time:</strong> </p>
        <p><strong>Attending:</strong> </p>
        <p><strong>Root cause:</strong> </p>

        <p><strong>Were we alerted quickly?</strong><br></p>
        <p><strong>Were we able to diagnose and fix the immediate issue quickly?</strong><br></p>
        <p><strong>How did we solve the problem?</strong><br></p>
        <p><strong>Was the process followed well, were comms effective?</strong><br></p>

        <p><strong>What could we do to prevent this from happening again?</strong></p>
        <ul><li> </li><li> </li><li> </li></ul>

        <p><strong>What could we do to improve our response?</strong></p>
        <ul><li> </li><li> </li><li> </li></ul>

        <p><strong>What could we do to improve comms/process?</strong></p>
        <ul><li> </li><li> </li><li> </li></ul>
      </body>
      </html>
    HTML
  end
end
