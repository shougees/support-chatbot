class HumanReview < ApplicationRecord
  STATUSES = %w[open in_review accepted denied resolved closed].freeze

  belongs_to :conversation
  belongs_to :message, optional: true
  belongs_to :operator_user, optional: true
  has_many :support_actions, dependent: :nullify

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
                         allow_nil: true
  validates :key_decision, presence: true

  scope :open, -> { where(status: "open") }
  scope :in_review, -> { where(status: "in_review") }
  scope :resolved, -> { where(status: %w[accepted denied resolved closed]) }
end
