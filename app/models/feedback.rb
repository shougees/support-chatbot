class Feedback < ApplicationRecord
  self.table_name = "feedbacks"

  RATINGS = %w[helpful not_helpful].freeze

  belongs_to :message

  validates :rating, presence: true, inclusion: { in: RATINGS }
  validate :message_is_assistant

  private

  def message_is_assistant
    return if message.blank? || message.assistant?

    errors.add(:message, "must be an assistant message")
  end
end
