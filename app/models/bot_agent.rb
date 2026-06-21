class BotAgent < ApplicationRecord
  PROVIDERS = %w[openai openai_compatible].freeze

  validates :name, presence: true
  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :llm_model, presence: true

  has_many :response_drafts, dependent: :nullify

  scope :active, -> { where(active: true) }

  # Returns the current active bot agent, or nil if none is configured.
  def self.current
    active.first
  end
end
