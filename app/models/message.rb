class Message < ApplicationRecord
  ROLES = %w[user assistant system].freeze

  belongs_to :conversation
  belongs_to :author, polymorphic: true, optional: true

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :body, presence: true

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
