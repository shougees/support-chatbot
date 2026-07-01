class KnowledgeDocumentIngestionJob < ApplicationJob
  queue_as :default

  def perform(knowledge_document)
    KnowledgeDocumentIngestor.call(knowledge_document)
  end
end
