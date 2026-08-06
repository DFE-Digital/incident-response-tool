class ReviewArtefact < ApplicationRecord
  belongs_to :incident

  serialize :timeline, JSON
  serialize :prevent_recurrence, JSON
  serialize :improve_response, JSON
  serialize :improve_process_comms, JSON

  validates :end_datetime, presence: true
  validates :technical_lead,   presence: { message: "Enter the technical lead" }
  validates :comms_lead,       presence: { message: "Enter the comms lead" }
  validates :support_lead,     presence: { message: "Enter the support lead" }
  validates :timeline_notes,   presence: { message: "Enter the timeline" }
  validates :resolution_notes, presence: { message: "Enter how the incident was resolved" }
end
