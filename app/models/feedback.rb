class Feedback < ApplicationRecord
  self.table_name = "feedbacks"

  RATINGS = %w[helpful not_helpful].freeze

  belongs_to :message

  validates :rating, presence: true, inclusion: { in: RATINGS }
  validate :message_is_support

  private

  def message_is_support
    return if message.blank? || message.support?

    errors.add(:message, "must be a support message")
  end
end
