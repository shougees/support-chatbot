require "test_helper"

class KnowledgeDocumentKeywordRetrieverTest < ActiveSupport::TestCase
  test "returns matching active knowledge documents" do
    matches = KnowledgeDocumentKeywordRetriever.call(question: "Can I get a refund for a missing order?")

    assert_equal [ knowledge_documents(:refund_policy) ], matches.map(&:document)
    assert_operator matches.first.score, :>, 0
  end

  test "returns no matches when the question does not match any document" do
    matches = KnowledgeDocumentKeywordRetriever.call(question: "How do I reset my thermostat?")

    assert_empty matches
  end

  test "excludes matching documents that are not active" do
    active_document = KnowledgeDocument.create!(
      title: "Active Refund Guidance",
      source_type: "manual",
      status: "active",
      body: "Refunds are available for missing orders when policy conditions are met."
    )

    %w[draft processing failed archived].each do |status|
      KnowledgeDocument.create!(
        title: "#{status.titleize} Refund Guidance",
        source_type: "manual",
        status: status,
        body: "Refunds are available for missing orders when policy conditions are met."
      )
    end

    matches = KnowledgeDocumentKeywordRetriever.call(question: "Can I get a refund for a missing order?")

    assert_equal [ active_document, knowledge_documents(:refund_policy) ].sort_by(&:id), matches.map(&:document).sort_by(&:id)
  end

  test "caps results to the provided limit" do
    top_match = KnowledgeDocument.create!(
      title: "Teakettle Lantern Marmalade Overflow",
      source_type: "manual",
      status: "active",
      body: "Teakettle lantern marmalade overflow."
    )
    second_match = KnowledgeDocument.create!(
      title: "Teakettle Lantern Marmalade",
      source_type: "manual",
      status: "active",
      body: "Teakettle lantern marmalade."
    )
    KnowledgeDocument.create!(
      title: "Teakettle Lantern",
      source_type: "manual",
      status: "active",
      body: "Teakettle lantern."
    )

    matches = KnowledgeDocumentKeywordRetriever.call(
      question: "Teakettle lantern marmalade overflow",
      limit: 2
    )

    assert_equal [ top_match, second_match ], matches.map(&:document)
  end

  test "matches seeded return policy language for package return questions" do
    SupportKnowledgeSeeder.call

    matches = KnowledgeDocumentKeywordRetriever.call(question: "Can I return my package?")

    assert_includes matches.map(&:document), KnowledgeDocument.find_by!(source_identifier: "seed/policy/returns")
  end

  test "prioritizes seeded delivery guidance for order tracking questions" do
    SupportKnowledgeSeeder.call

    matches = KnowledgeDocumentKeywordRetriever.call(question: "Where is my order?")

    assert_equal KnowledgeDocument.find_by!(source_identifier: "seed/policy/missing-late-delivery"), matches.first.document
  end
end
