class Message < ApplicationRecord
  PUBLIC_ROLES = %w[customer support system].freeze
  ORIGINS = %w[
    customer_submitted
    bot_auto_sent
    bot_approved
    bot_edited
    operator_replacement
    operator_direct
    system_event
  ].freeze
  SUPPORT_ORIGINS = %w[
    bot_auto_sent
    bot_approved
    bot_edited
    operator_replacement
    operator_direct
  ].freeze

  belongs_to :conversation
  belongs_to :author, polymorphic: true, optional: true
  belongs_to :published_by, polymorphic: true, optional: true
  belongs_to :response_draft, optional: true
  has_many :retrieval_results, dependent: :destroy
  has_many :knowledge_documents, through: :retrieval_results
  has_many :response_reviews, dependent: :nullify
  has_many :support_actions, dependent: :nullify
  has_many :uploads, dependent: :nullify
  has_many :feedbacks, dependent: :destroy
  has_one :agent_decision_trace, dependent: :destroy

  after_create_commit :broadcast_conversation_updates

  validates :public_role, presence: true, inclusion: { in: PUBLIC_ROLES }
  validates :origin, presence: true, inclusion: { in: ORIGINS }
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 },
                       uniqueness: { scope: :conversation_id }
  validates :body, presence: true

  scope :chronological, -> { order(:conversation_id, :position, :created_at, :id) }
  scope :customer_messages, -> { where(public_role: "customer") }
  scope :support_messages, -> { where(public_role: "support") }
  scope :system_messages, -> { where(public_role: "system") }
  scope :customer_visible, -> { where(public_role: %w[customer support]) }

  def customer?
    public_role == "customer"
  end

  def support?
    public_role == "support"
  end

  def system?
    public_role == "system"
  end

  private

  def broadcast_conversation_updates
    conversation.broadcast_message_lists
  end
end
