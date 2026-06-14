require "test_helper"

class RetrievalResultTest < ActiveSupport::TestCase
  test "valid with required fields" do
    result = RetrievalResult.new(
      message: messages(:second_assistant_message),
      knowledge_document: knowledge_documents(:refund_policy),
      score: 0.75,
      rank: 1
    )

    assert result.valid?
  end

  test "belongs to message and knowledge document" do
    result = retrieval_results(:top_refund_result)

    assert_equal messages(:assistant_message), result.message
    assert_equal knowledge_documents(:refund_policy), result.knowledge_document
  end

  test "score cannot be negative" do
    result = retrieval_results(:top_refund_result)
    result.score = -0.1

    assert_not result.valid?
    assert_includes result.errors[:score], "must be greater than or equal to 0"
  end

  test "rank must be a positive integer" do
    result = retrieval_results(:top_refund_result)
    result.rank = 0

    assert_not result.valid?
    assert_includes result.errors[:rank], "must be greater than 0"
  end

  test "rank is unique per message" do
    result = RetrievalResult.new(
      message: messages(:assistant_message),
      knowledge_document: knowledge_documents(:refund_policy),
      score: 0.75,
      rank: 1
    )

    assert_not result.valid?
    assert_includes result.errors[:rank], "has already been taken"
  end

  test "knowledge document is unique per message" do
    result = RetrievalResult.new(
      message: messages(:assistant_message),
      knowledge_document: knowledge_documents(:refund_policy),
      score: 0.75,
      rank: 3
    )

    assert_not result.valid?
    assert_includes result.errors[:knowledge_document_id], "has already been taken"
  end

  test "ranked scope orders by rank" do
    ranks = RetrievalResult.where(message: messages(:assistant_message)).ranked.pluck(:rank)

    assert_equal ranks.sort, ranks
  end
end
