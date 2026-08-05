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
end
