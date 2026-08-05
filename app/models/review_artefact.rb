class ReviewArtefact < ApplicationRecord
  belongs_to :incident

  serialize :timeline, JSON
  serialize :prevent_recurrence, JSON
  serialize :improve_response, JSON
  serialize :improve_process_comms, JSON

  validates :end_datetime, presence: true
end
