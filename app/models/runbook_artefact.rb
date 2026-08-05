class RunbookArtefact < ApplicationRecord
  belongs_to :incident

  serialize :steps, JSON

  MATCH_TYPES = %w[retrieved drafted refused].freeze

  validates :match_type, inclusion: { in: MATCH_TYPES }
  validates :owner_to_escalate_to, presence: true

  def retrieved?
    match_type == "retrieved"
  end

  def drafted?
    match_type == "drafted"
  end

  def refused?
    match_type == "refused"
  end
end
