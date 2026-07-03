class Escalation < ApplicationRecord
  STATUSES = %w[pending in_progress resolved canceled].freeze
  REASONS = %w[
    low_confidence
    direct_handoff_request
    repeated_handoff_request
    high_risk
    provider_failure
    policy_review
    action_requires_review
  ].freeze

  belongs_to :conversation
  belongs_to :message, optional: true
  belongs_to :response_review, optional: true
  belongs_to :operator_user, optional: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :reason, presence: true, inclusion: { in: REASONS }
  validates :summary, presence: true
  validate :message_belongs_to_conversation
  validate :review_belongs_to_conversation

  scope :active, -> { where(status: %w[pending in_progress]) }
  scope :resolved, -> { where(status: "resolved") }

  def metadata_hash
    JSON.parse(metadata.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def update_status!(status:, operator_user: nil)
    assign_attributes(
      status: status,
      operator_user: operator_user || self.operator_user,
      resolved_at: resolved_terminal_status?(status) ? Time.current : nil
    )
    save!
  end

  private

  def message_belongs_to_conversation
    return if message.blank? || conversation.blank? || message.conversation_id == conversation_id

    errors.add(:message, "must belong to the same conversation")
  end

  def review_belongs_to_conversation
    return if response_review.blank? || conversation.blank? || response_review.conversation_id == conversation_id

    errors.add(:response_review, "must belong to the same conversation")
  end

  def resolved_terminal_status?(status)
    %w[resolved canceled].include?(status)
  end
end
