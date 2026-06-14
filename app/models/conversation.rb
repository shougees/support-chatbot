class Conversation < ApplicationRecord
  STATUSES = %w[open pending_human_review resolved closed].freeze

  belongs_to :customer, optional: true
  has_many :messages, dependent: :destroy
  has_many :human_reviews, dependent: :destroy
  has_many :support_actions, dependent: :destroy
  has_many :uploads, dependent: :destroy

  validates :public_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  before_validation :generate_public_id, on: :create

  scope :open, -> { where(status: "open") }
  scope :pending_human_review, -> { where(status: "pending_human_review") }
  scope :resolved, -> { where(status: "resolved") }
  scope :closed, -> { where(status: "closed") }

  def pending_human_review?
    status == "pending_human_review"
  end

  def resolved?
    status == "resolved"
  end

  def closed?
    status == "closed"
  end

  private

  def generate_public_id
    self.public_id ||= SecureRandom.uuid
  end
end
