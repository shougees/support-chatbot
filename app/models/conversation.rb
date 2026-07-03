class Conversation < ApplicationRecord
  STATUSES = %w[open waiting_on_customer waiting_on_bot pending_operator_review closed].freeze

  after_update_commit :broadcast_status_panels

  belongs_to :customer, optional: true
  has_many :messages, dependent: :destroy
  has_many :response_drafts, dependent: :destroy
  has_many :response_reviews, dependent: :destroy
  has_many :support_actions, dependent: :destroy
  has_many :uploads, dependent: :destroy
  has_many :agent_decision_traces, dependent: :destroy
  has_many :escalations, dependent: :destroy

  validates :public_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  before_validation :generate_public_id, on: :create

  scope :open, -> { where(status: "open") }
  scope :waiting_on_customer, -> { where(status: "waiting_on_customer") }
  scope :waiting_on_bot, -> { where(status: "waiting_on_bot") }
  scope :pending_operator_review, -> { where(status: "pending_operator_review") }
  scope :closed, -> { where(status: "closed") }

  def active_escalation
    escalations.active.order(:created_at).first
  end

  def escalated?
    active_escalation.present?
  end

  def customer_visible_messages
    messages.customer_visible.chronological
  end

  def publish_customer_message!(body:, customer: self.customer)
    with_lock do
      messages.create!(
        public_role: "customer",
        origin: "customer_submitted",
        author: customer,
        published_by: customer,
        body: body,
        position: next_message_position
      ).tap do
        update!(status: "waiting_on_bot") unless closed?
      end
    end
  end

  def publish_support_message!(body:, origin:, author:, published_by:, response_draft: nil)
    unless Message::SUPPORT_ORIGINS.include?(origin)
      raise ArgumentError, "origin must be a support message origin"
    end

    with_lock do
      messages.create!(
        public_role: "support",
        origin: origin,
        author: author,
        published_by: published_by,
        response_draft: response_draft,
        body: body,
        position: next_message_position
      ).tap do
        update!(status: "waiting_on_customer") unless closed?
      end
    end
  end

  def open?
    status == "open"
  end

  def waiting_on_customer?
    status == "waiting_on_customer"
  end

  def waiting_on_bot?
    status == "waiting_on_bot"
  end

  def pending_operator_review?
    status == "pending_operator_review"
  end

  def closed?
    status == "closed"
  end

  def broadcast_message_lists
    broadcast_replace_to(
      self,
      target: dom_target(:messages),
      partial: "conversations/message_list",
      locals: { conversation: self }
    )
    broadcast_replace_to(
      self,
      target: dom_target(:operator_transcript),
      partial: "operator/conversations/transcript",
      locals: { conversation: self }
    )
  end

  def broadcast_status_panels
    broadcast_replace_to(
      self,
      target: dom_target(:customer_status),
      partial: "conversations/status",
      locals: { conversation: self }
    )
    broadcast_replace_to(
      self,
      target: dom_target(:operator_status),
      partial: "operator/conversations/status",
      locals: { conversation: self }
    )
  end

  def broadcast_operator_response_drafts
    broadcast_replace_to(
      self,
      target: dom_target(:operator_response_drafts),
      partial: "operator/conversations/response_drafts",
      locals: { conversation: self }
    )
  end

  private

  def dom_target(prefix)
    ActionView::RecordIdentifier.dom_id(self, prefix)
  end

  def next_message_position
    messages.maximum(:position).to_i + 1
  end

  def generate_public_id
    self.public_id ||= SecureRandom.uuid
  end
end
