class ResponseReview < ApplicationRecord
  STATUSES = %w[pending approved edited rejected resolved].freeze

  belongs_to :conversation
  belongs_to :message, optional: true
  belongs_to :response_draft
  belongs_to :operator_user, optional: true
  has_one :agent_decision_trace, dependent: :nullify
  has_one :escalation, dependent: :nullify
  has_many :support_actions, dependent: :nullify

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :key_decision, presence: true

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :rejected, -> { where(status: "rejected") }
  scope :resolved, -> { where(status: "resolved") }
end
