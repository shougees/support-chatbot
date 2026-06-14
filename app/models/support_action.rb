class SupportAction < ApplicationRecord
  ACTION_TYPES = %w[refund return replacement credit cancellation operator_review].freeze
  STATUSES = %w[proposed approved denied completed failed requires_review].freeze

  belongs_to :conversation
  belongs_to :message, optional: true
  belongs_to :response_review, optional: true

  validates :action_type, presence: true, inclusion: { in: ACTION_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :proposed, -> { where(status: "proposed") }
  scope :requires_review, -> { where(status: "requires_review") }
  scope :completed, -> { where(status: "completed") }
end
