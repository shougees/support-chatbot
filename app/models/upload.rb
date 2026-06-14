class Upload < ApplicationRecord
  FILE_TYPES = %w[image document other].freeze
  PROCESSING_STATUSES = %w[pending processing completed failed].freeze

  belongs_to :conversation
  belongs_to :message, optional: true

  validates :file_type, presence: true, inclusion: { in: FILE_TYPES }
  validates :processing_status, presence: true, inclusion: { in: PROCESSING_STATUSES }
end
