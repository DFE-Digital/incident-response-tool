class IncidentsController < ApplicationController
  def new
    @incident = Incident.new
  end

  def create
    @incident = Incident.new(incident_params)

    if @incident.save
      TeamsNotifier.incident_opened(@incident)
      redirect_to @incident
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @incident = Incident.find(params[:id])
  end

  private

  def incident_params
    params.require(:incident).permit(:title, :description, :service)
  end
end
