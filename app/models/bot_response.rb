class BotResponse < ApplicationRecord
  UPLOAD_TYPES = %w[image document either].freeze

  belongs_to :message

  validates :message_id, uniqueness: true
  validates :confidence, presence: true,
                         numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :upload_type, inclusion: { in: UPLOAD_TYPES }, allow_blank: true
  validate :message_is_assistant

  scope :low_confidence, ->(threshold = 70) { where("confidence < ?", threshold) }
  scope :human_review_recommended, -> { where(human_review_recommended: true) }

  private

  def message_is_assistant
    return if message.blank? || message.assistant?

    errors.add(:message, "must be an assistant message")
  end
end
