class RetrievalResult < ApplicationRecord
  belongs_to :message
  belongs_to :knowledge_document

  validates :score, numericality: { greater_than_or_equal_to: 0 }
  validates :rank, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :rank, uniqueness: { scope: :message_id }
  validates :knowledge_document_id, uniqueness: { scope: :message_id }

  scope :ranked, -> { order(:rank) }
end
