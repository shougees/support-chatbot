class KnowledgeDocument < ApplicationRecord
  SOURCE_TYPES = %w[manual upload url reddit].freeze
  STATUSES = %w[draft processing active failed archived].freeze

  has_many :retrieval_results, dependent: :destroy
  has_many :messages, through: :retrieval_results

  validates :title, presence: true
  validates :source_type, presence: true, inclusion: { in: SOURCE_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :has_body_or_extracted_text

  scope :active, -> { where(status: "active") }
  scope :retrievable, -> { active }

  private

  def has_body_or_extracted_text
    return if body.present? || extracted_text.present?

    errors.add(:base, "body or extracted text must be present")
  end
end
