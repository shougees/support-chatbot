class Message < ApplicationRecord
  ROLES = %w[user assistant system].freeze

  belongs_to :conversation
  belongs_to :author, polymorphic: true, optional: true
  has_one :bot_response, dependent: :destroy
  has_many :retrieval_results, dependent: :destroy
  has_many :knowledge_documents, through: :retrieval_results
  has_many :human_reviews, dependent: :nullify
  has_many :support_actions, dependent: :nullify
  has_many :uploads, dependent: :nullify
  has_many :feedbacks, dependent: :destroy

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :body, presence: true

  scope :chronological, -> { order(:created_at, :id) }
  scope :user_messages, -> { where(role: "user") }
  scope :assistant_messages, -> { where(role: "assistant") }
  scope :system_messages, -> { where(role: "system") }

  def user?
    role == "user"
  end

  def assistant?
    role == "assistant"
  end

  def system?
    role == "system"
  end
end
