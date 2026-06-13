class Conversation < ApplicationRecord
  STATUSES = %w[open escalated resolved closed].freeze

  has_many :messages, dependent: :destroy

  validates :public_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  before_validation :generate_public_id, on: :create

  scope :open, -> { where(status: "open") }
  scope :escalated, -> { where(status: "escalated") }
  scope :resolved, -> { where(status: "resolved") }
  scope :closed, -> { where(status: "closed") }

  def escalated?
    status == "escalated"
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
