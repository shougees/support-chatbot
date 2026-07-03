class Upload < ApplicationRecord
  FILE_TYPES = %w[image document other].freeze
  PROCESSING_STATUSES = %w[pending processing completed failed].freeze
  IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
  DOCUMENT_CONTENT_TYPES = %w[application/pdf text/plain].freeze
  ALLOWED_CONTENT_TYPES = (IMAGE_CONTENT_TYPES + DOCUMENT_CONTENT_TYPES).freeze

  belongs_to :conversation
  belongs_to :message, optional: true

  has_one_attached :file

  validates :file_type, presence: true, inclusion: { in: FILE_TYPES }
  validates :processing_status, presence: true, inclusion: { in: PROCESSING_STATUSES }
  validate :file_content_type_is_supported
  validate :image_file_type_uses_image_content
  validate :document_file_type_uses_document_content
  validate :message_belongs_to_conversation

  def file_content_type
    file.blob&.content_type if file.attached?
  end

  private

  def file_content_type_is_supported
    return unless file.attached?
    return if ALLOWED_CONTENT_TYPES.include?(file_content_type)

    errors.add(:file, "content type is not supported")
  end

  def image_file_type_uses_image_content
    return unless file.attached? && file_type == "image"
    return if IMAGE_CONTENT_TYPES.include?(file_content_type)

    errors.add(:file, "must be an image")
  end

  def document_file_type_uses_document_content
    return unless file.attached? && file_type == "document"
    return if DOCUMENT_CONTENT_TYPES.include?(file_content_type)

    errors.add(:file, "must be a supported document")
  end

  def message_belongs_to_conversation
    return if message.blank? || conversation.blank?
    return if message.conversation_id == conversation_id

    errors.add(:message, "must belong to the same conversation")
  end
end
