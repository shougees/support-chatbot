class Bot < ApplicationRecord
  PROVIDERS = %w[openai].freeze

  validates :name, presence: true
  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :llm_model, presence: true

  scope :active, -> { where(active: true) }

  # Returns the current active Bot, or nil if none is configured.
  def self.current
    active.first
  end
end
