class IncidentsController < ApplicationController
  def index
    @status_filter = params[:status].to_s.presence_in(Incident::STATUSES)
    scope = Incident.includes(:process_artefact, :runbook_artefact, :review_artefact).recent
    @incidents = @status_filter ? scope.where(status: @status_filter) : scope
    @counts = {
      "all"      => Incident.count,
      "open"     => Incident.where(status: "open").count,
      "resolved" => Incident.where(status: "resolved").count,
    }
  end

  def new
    @incident = Incident.new
  end

  def create
    @incident = Incident.new(incident_params)

    unless @incident.save
      render :new, status: :unprocessable_entity
      return
    end

    TeamsNotifier.incident_opened(@incident)

    # Generate the process artefact eagerly. The incident must remain
    # created and visible even if the model call fails — the show page
    # still offers a retry when process_artefact is nil.
    begin
      ClaudeProcessService.new(@incident).call
    rescue JSON::ParserError
      flash[:alert] = "Claude returned an unexpected response — retry generating the process below."
    rescue KeyError => e
      flash[:alert] = "Response was missing a required field (#{e.message}) — retry generating the process below."
    rescue StandardError => e
      Rails.logger.error("Process generation failed on incident #{@incident.id}: #{e.class} #{e.message}")
      flash[:alert] = "Couldn't generate the process just now — retry below."
    end

    redirect_to @incident
  end

  def show
    @incident = Incident.find(params[:id])
  end

  private

  def incident_params
    params.require(:incident).permit(:title, :description, :service)
  end
end
