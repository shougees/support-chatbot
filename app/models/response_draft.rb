class ResponseDraft < ApplicationRecord
  STATUSES = %w[draft pending_review approved rejected published].freeze
  UPLOAD_TYPES = %w[image document either].freeze

  after_commit :broadcast_operator_updates, on: %i[create update]

  belongs_to :conversation
  belongs_to :bot_agent, optional: true
  has_one :published_message, class_name: "Message", foreign_key: :response_draft_id, dependent: :nullify
  has_one :agent_decision_trace, dependent: :nullify
  has_many :response_reviews, dependent: :destroy

  validates :body, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :confidence, presence: true,
                         numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :upload_type, inclusion: { in: UPLOAD_TYPES }, allow_blank: true

  scope :low_confidence, ->(threshold = 70) { where("confidence < ?", threshold) }
  scope :pending_review, -> { where(status: "pending_review") }

  def metadata_hash
    JSON.parse(metadata.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def publish_approved!(operator_user:)
    publish_reviewed_response!(
      body: body,
      origin: "bot_approved",
      author: bot_agent,
      operator_user: operator_user,
      review_status: "approved",
      final_draft_status: "published"
    )
  end

  def publish_edited!(operator_user:, body:)
    publish_reviewed_response!(
      body: body,
      origin: "bot_edited",
      author: bot_agent,
      operator_user: operator_user,
      review_status: "edited",
      final_draft_status: "published",
      review_attributes: { edited_body: body }
    )
  end

  def publish_replacement!(operator_user:, body:)
    publish_reviewed_response!(
      body: body,
      origin: "operator_replacement",
      author: operator_user,
      operator_user: operator_user,
      review_status: "rejected",
      final_draft_status: "rejected",
      review_attributes: { agent_response: body }
    )
  end

  private

  def broadcast_operator_updates
    conversation.broadcast_operator_response_drafts
  end

  def publish_reviewed_response!(body:, origin:, author:, operator_user:, review_status:, final_draft_status:, review_attributes: {})
    transaction do
      lock!
      ensure_publishable!

      message = conversation.publish_support_message!(
        body: body,
        origin: origin,
        author: author,
        published_by: operator_user,
        response_draft: self
      )

      review = response_reviews.pending.order(:created_at).first || response_reviews.build(
        conversation: conversation,
        key_decision: "response_publication"
      )
      review.assign_attributes(
        {
          status: review_status,
          operator_user: operator_user,
          message: message
        }.merge(review_attributes)
      )
      review.key_decision ||= "response_publication"
      review.save!

      update!(status: final_draft_status)
      message
    end
  end

  def ensure_publishable!
    association(:published_message).reset
    return unless published_message.present? || status == "published"

    errors.add(:base, "has already been published")
    raise ActiveRecord::RecordInvalid, self
  end
end
