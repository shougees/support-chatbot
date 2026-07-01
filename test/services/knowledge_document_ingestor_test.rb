require "test_helper"

class KnowledgeDocumentIngestorTest < ActiveSupport::TestCase
  test "manual ingestion copies body into extracted text and activates the document" do
    document = KnowledgeDocument.create!(
      title: "Manual Return Policy",
      source_type: "manual",
      source_identifier: "manual/returns",
      category: "returns",
      body: " Returns are available within 30 days. ",
      status: "draft",
      metadata: { tags: %w[returns policy] }.to_json
    )

    result = KnowledgeDocumentIngestor.call(document)

    assert result.success?
    assert_equal "active", document.reload.status
    assert_equal "Returns are available within 30 days.", document.extracted_text
    assert_equal %w[returns policy], document.metadata_hash["tags"]
    assert_equal "completed", document.metadata_hash.dig("ingestion", "status")
    assert_equal "manual", document.metadata_hash.dig("ingestion", "source_type")
    assert_not_nil document.metadata_hash.dig("ingestion", "completed_at")
  end

  test "url ingestion is represented but disabled" do
    document = KnowledgeDocument.create!(
      title: "Public Returns Page",
      source_type: "url",
      source_identifier: "https://example.com/returns",
      category: "returns",
      status: "draft"
    )

    result = KnowledgeDocumentIngestor.call(document)

    assert_not result.success?
    assert_equal "failed", document.reload.status
    assert_equal "URL ingestion is not implemented yet.", result.error_message
    assert_equal "URL ingestion is not implemented yet.", document.metadata_hash.dig("ingestion", "error")
    assert_equal true, document.metadata_hash.dig("ingestion", "disabled")
  end

  test "reddit ingestion is represented but disabled" do
    document = KnowledgeDocument.create!(
      title: "Reddit Delivery Thread",
      source_type: "reddit",
      source_identifier: "reddit/support/example",
      category: "delivery",
      status: "draft"
    )

    result = KnowledgeDocumentIngestor.call(document)

    assert_not result.success?
    assert_equal "failed", document.reload.status
    assert_equal "Reddit ingestion is not implemented yet.", result.error_message
    assert_equal "reddit", document.metadata_hash.dig("ingestion", "source_type")
  end

  test "manual ingestion marks failed when body cannot be extracted" do
    document = KnowledgeDocument.create!(
      title: "Manual Empty Policy",
      source_type: "manual",
      source_identifier: "manual/empty",
      category: "returns",
      body: "Placeholder",
      status: "draft"
    )
    document.update_columns(body: nil, extracted_text: nil)

    result = KnowledgeDocumentIngestor.call(document)

    assert_not result.success?
    assert_equal "failed", document.reload.status
    assert_equal "Manual source body is blank.", result.error_message
    assert_equal "Manual source body is blank.", document.metadata_hash.dig("ingestion", "error")
  end
end
