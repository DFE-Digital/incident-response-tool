class ProcessArtefact < ApplicationRecord
  belongs_to :incident

  serialize :immediate_actions, Array
  serialize :communication_actions, Array
  serialize :escalation_path, Array

  SEVERITIES = %w[P1 P2 P3 P4].freeze
end
