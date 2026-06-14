class ResponseDraft < ApplicationRecord
  STATUSES = %w[draft pending_review approved rejected published].freeze
  UPLOAD_TYPES = %w[image document either].freeze

  belongs_to :conversation
  belongs_to :bot_agent, optional: true
  has_one :published_message, class_name: "Message", foreign_key: :response_draft_id, dependent: :nullify
  has_many :response_reviews, dependent: :destroy

  validates :body, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :confidence, presence: true,
                         numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :upload_type, inclusion: { in: UPLOAD_TYPES }, allow_blank: true

  scope :low_confidence, ->(threshold = 70) { where("confidence < ?", threshold) }
  scope :pending_review, -> { where(status: "pending_review") }
end
