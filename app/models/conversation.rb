class Conversation < ApplicationRecord
  STATUSES = %w[open waiting_on_customer waiting_on_bot pending_operator_review closed].freeze

  belongs_to :customer, optional: true
  has_many :messages, dependent: :destroy
  has_many :response_drafts, dependent: :destroy
  has_many :response_reviews, dependent: :destroy
  has_many :support_actions, dependent: :destroy
  has_many :uploads, dependent: :destroy

  validates :public_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  before_validation :generate_public_id, on: :create

  scope :open, -> { where(status: "open") }
  scope :waiting_on_customer, -> { where(status: "waiting_on_customer") }
  scope :waiting_on_bot, -> { where(status: "waiting_on_bot") }
  scope :pending_operator_review, -> { where(status: "pending_operator_review") }
  scope :closed, -> { where(status: "closed") }

  def pending_operator_review?
    status == "pending_operator_review"
  end

  def closed?
    status == "closed"
  end

  private

  def generate_public_id
    self.public_id ||= SecureRandom.uuid
  end
end
