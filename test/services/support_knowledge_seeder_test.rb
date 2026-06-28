require "test_helper"

class SupportKnowledgeSeederTest < ActiveSupport::TestCase
  setup do
    KnowledgeDocument.where(source_identifier: seeded_source_identifiers).delete_all
  end

  test "creates active original ecommerce support policy documents" do
    assert_difference("KnowledgeDocument.active.count", SupportKnowledgeSeeder::DOCUMENTS.size) do
      SupportKnowledgeSeeder.call
    end

    seeded_documents = KnowledgeDocument.where(source_identifier: seeded_source_identifiers)

    assert_equal SupportKnowledgeSeeder::DOCUMENTS.size, seeded_documents.count
    assert seeded_documents.all? { |document| document.status == "active" }
    assert_equal %w[account damaged_items delivery order_changes refunds returns], seeded_documents.pluck(:category).sort
  end

  test "running seeder twice updates documents without duplicating them" do
    SupportKnowledgeSeeder.call

    assert_no_difference("KnowledgeDocument.count") do
      SupportKnowledgeSeeder.call
    end
  end

  test "seeded policies are retrievable for common support questions" do
    SupportKnowledgeSeeder.call

    return_matches = KnowledgeDocumentKeywordRetriever.call(question: "Can I return my package?")
    damaged_matches = KnowledgeDocumentKeywordRetriever.call(question: "My item arrived damaged and broken, can I send a photo?")
    delivery_matches = KnowledgeDocumentKeywordRetriever.call(question: "Where is my late delivery tracking update?")

    assert_includes return_matches.map { |match| match.document.title }, "Return Eligibility Policy"
    assert_includes damaged_matches.map { |match| match.document.title }, "Damaged Item Evidence Policy"
    assert_includes delivery_matches.map { |match| match.document.title }, "Missing Or Late Delivery Guidance"
  end

  private

  def seeded_source_identifiers
    SupportKnowledgeSeeder::DOCUMENTS.map { |document| document.fetch(:source_identifier) }
  end
end
