require "test_helper"

class OperatorConversationsControllerTest < ActionDispatch::IntegrationTest
  test "shows source document titles for messages with retrieval results" do
    get operator_conversation_url(conversations(:open_conversation).public_id)

    assert_response :success
    assert_select "p", text: /Sources/i
    assert_select "li", text: /Refund Policy/
  end

  test "shows deleted document fallback when source document no longer exists" do
    ActiveRecord::Base.connection.disable_referential_integrity do
      retrieval_results(:top_refund_result).update_column(:knowledge_document_id, 0)
    end

    get operator_conversation_url(conversations(:open_conversation).public_id)

    assert_response :success
    assert_select "li", text: /Deleted document/
  end

  test "renders transcript without sources section when no retrieval results exist" do
    conversation = conversations(:pending_operator_review_conversation)

    get operator_conversation_url(conversation.public_id)

    assert_response :success
    assert_select "article"
    assert_select "p", text: /Sources/i, count: 0
  end
end
