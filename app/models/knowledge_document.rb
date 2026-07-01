class KnowledgeDocument < ApplicationRecord
  SOURCE_TYPES = %w[manual upload url reddit].freeze
  STATUSES = %w[draft processing active failed archived].freeze

  has_many :retrieval_results, dependent: :destroy
  has_many :messages, through: :retrieval_results

  validates :title, presence: true
  validates :source_type, presence: true, inclusion: { in: SOURCE_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :has_ingestable_content_or_identifier

  scope :active, -> { where(status: "active") }
  scope :retrievable, -> { active }

  def self.ingest_later(document)
    KnowledgeDocumentIngestionJob.perform_later(document)
  end

  def metadata_hash
    JSON.parse(metadata.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def ingest_later
    self.class.ingest_later(self)
  end

  private

  def has_ingestable_content_or_identifier
    return if status == "failed"
    return if body.present? || extracted_text.present?
    return if source_type != "manual" && source_identifier.present?

    errors.add(:base, "body or extracted text must be present")
  end
end
