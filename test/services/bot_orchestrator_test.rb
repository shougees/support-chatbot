require "test_helper"

class BotOrchestratorTest < ActiveSupport::TestCase
  test "publishes a support message when confidence is above threshold" do
    conversation = Conversation.create!(customer: customers(:one), status: "waiting_on_bot")
    customer_message = conversation.publish_customer_message!(body: "Where is my order?", customer: customers(:one))

    result = BotOrchestrator.call(conversation: conversation, message: customer_message)

    assert result.published?
    assert_not result.pending_review?
    assert_equal "published", result.response_draft.status
    assert_equal "support", result.message.public_role
    assert_equal "bot_auto_sent", result.message.origin
    assert_equal bot_agents(:support_bot), result.message.author
    assert_equal bot_agents(:support_bot), result.message.published_by
    assert_equal result.response_draft, result.message.response_draft
    assert_equal "waiting_on_customer", conversation.reload.status
  end

  test "records retrieval results for matching active knowledge documents" do
    conversation = Conversation.create!(customer: customers(:one), status: "waiting_on_bot")
    customer_message = conversation.publish_customer_message!(body: "My order is missing. Is a refund possible?", customer: customers(:one))

    result = BotOrchestrator.call(conversation: conversation, message: customer_message)

    assert_includes result.retrieval_results.map(&:knowledge_document), knowledge_documents(:refund_policy)
    assert_equal [ 1 ], customer_message.retrieval_results.ranked.pluck(:rank)
  end

  test "requests an upload when item condition evidence is useful" do
    conversation = Conversation.create!(customer: customers(:one), status: "waiting_on_bot")
    customer_message = conversation.publish_customer_message!(body: "My item arrived damaged and broken.", customer: customers(:one))

    result = BotOrchestrator.call(conversation: conversation, message: customer_message)

    assert result.published?
    assert result.response_draft.upload_requested?
    assert_equal "image", result.response_draft.upload_type
    assert_match "upload", result.message.body
    assert_equal "waiting_on_customer", conversation.reload.status
  end

  test "routes low confidence action decisions to operator review" do
    conversation = Conversation.create!(customer: customers(:one), status: "waiting_on_bot")
    customer_message = conversation.publish_customer_message!(body: "Can we get a refund for this order?", customer: customers(:one))

    result = BotOrchestrator.call(conversation: conversation, message: customer_message)

    assert_not result.published?
    assert result.pending_review?
    assert_equal "pending_review", result.response_draft.status
    assert_equal "pending", result.response_review.status
    assert_equal "response_publication", result.response_review.key_decision
    assert_equal "pending_operator_review", conversation.reload.status
    assert_not_nil conversation.operator_review_requested_at
  end

  test "creates fallback review when no bot agent is configured" do
    BotAgent.update_all(active: false)
    conversation = Conversation.create!(customer: customers(:one), status: "waiting_on_bot")
    customer_message = conversation.publish_customer_message!(body: "Where is my order?", customer: customers(:one))

    result = BotOrchestrator.call(conversation: conversation, message: customer_message)

    assert_not result.published?
    assert result.pending_review?
    assert_nil result.response_draft.bot_agent
    assert_equal "fallback", result.response_draft.category
    assert_equal 0, result.response_draft.confidence
    assert_equal "No active bot agent is configured.", result.response_review.reason
  end

  test "uses an injected provider response" do
    provider = Class.new do
      def call(conversation:, message:, bot_agent:, retrieved_documents:)
        {
          body: "Provider-generated support reply.",
          confidence: 91,
          category: "provider_test",
          status: "draft",
          raw_provider_response: "provider_payload"
        }
      end
    end.new
    conversation = Conversation.create!(customer: customers(:one), status: "waiting_on_bot")
    customer_message = conversation.publish_customer_message!(body: "Need order help.", customer: customers(:one))

    result = BotOrchestrator.call(conversation: conversation, message: customer_message, provider: provider)

    assert result.published?
    assert_equal "Provider-generated support reply.", result.message.body
    assert_equal "provider_test", result.response_draft.category
    assert_equal "provider_payload", result.response_draft.raw_provider_response
  end

  test "requires the message to belong to the conversation" do
    other_conversation = conversations(:pending_operator_review_conversation)

    assert_raises(ArgumentError) do
      BotOrchestrator.call(conversation: conversations(:open_conversation), message: other_conversation.messages.first)
    end
  end

  test "requires a customer message" do
    assert_raises(ArgumentError) do
      BotOrchestrator.call(conversation: conversations(:open_conversation), message: messages(:support_message))
    end
  end
end
