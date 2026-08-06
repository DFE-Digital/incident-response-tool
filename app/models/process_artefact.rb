class ProcessArtefact < ApplicationRecord
  belongs_to :incident

  serialize :immediate_actions,    coder: YAML, type: Array
  serialize :communication_actions, coder: YAML, type: Array
  serialize :escalation_path,       coder: YAML, type: Array

  SEVERITIES = %w[P1 P2 P3 P4].freeze
end
