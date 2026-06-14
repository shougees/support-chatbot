require "test_helper"

class KnowledgeDocumentTest < ActiveSupport::TestCase
  test "valid with required fields and body" do
    document = KnowledgeDocument.new(title: "Return Policy", source_type: "manual", status: "active", body: "Policy text")

    assert document.valid?
  end

  test "valid with extracted text instead of body" do
    document = KnowledgeDocument.new(title: "Imported Source", source_type: "upload", status: "processing", extracted_text: "Parsed text")

    assert document.valid?
  end

  test "requires title" do
    document = knowledge_documents(:refund_policy)
    document.title = nil

    assert_not document.valid?
    assert_includes document.errors[:title], "can't be blank"
  end

  test "requires valid source type and status" do
    document = KnowledgeDocument.new(title: "Bad Source", source_type: "unknown", status: "unknown", body: "Body")

    assert_not document.valid?
    assert_includes document.errors[:source_type], "is not included in the list"
    assert_includes document.errors[:status], "is not included in the list"
  end

  test "requires body or extracted text" do
    document = KnowledgeDocument.new(title: "Empty Source", source_type: "manual", status: "draft")

    assert_not document.valid?
    assert_includes document.errors[:base], "body or extracted text must be present"
  end

  test "has retrieval results and messages" do
    document = knowledge_documents(:refund_policy)

    assert_equal 1, document.retrieval_results.count
    assert_includes document.messages, messages(:assistant_message)
  end

  test "active and retrievable scopes return active documents" do
    assert_includes KnowledgeDocument.active, knowledge_documents(:refund_policy)
    assert_not KnowledgeDocument.retrievable.include?(knowledge_documents(:reddit_signal))
  end
end
