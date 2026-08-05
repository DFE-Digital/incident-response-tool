class Incident < ApplicationRecord
  has_one :process_artefact, dependent: :destroy
  has_one :runbook_artefact, dependent: :destroy
  has_one :review_artefact, dependent: :destroy

  SERVICES = [
    "Get Help Buying for Schools",
    "Child Development Training",
    "Help for Early Years Providers",
    "Other",
  ].freeze

  STATUSES = %w[open resolved].freeze

  validates :title, presence: true
  validates :description, presence: true
  validates :service, presence: true, inclusion: { in: SERVICES }
  validates :status, inclusion: { in: STATUSES }

  scope :open, -> { where(status: "open") }
  scope :resolved, -> { where(status: "resolved") }
  scope :recent, -> { order(created_at: :desc) }
end
