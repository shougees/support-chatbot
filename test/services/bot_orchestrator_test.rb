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
    assert_equal 0, conversation.support_actions.count, "auto-published responses must not create support actions"
    assert_equal "answered_directly", result.agent_decision_trace.outcome
    assert_equal customer_message, result.agent_decision_trace.message
    assert_equal result.message, result.agent_decision_trace.published_message
    assert_equal "openai", result.agent_decision_trace.provider_name
    assert_equal "gpt-4o", result.agent_decision_trace.provider_model
    assert_equal "general_support", result.agent_decision_trace.response_category
    assert_not result.agent_decision_trace.review_required?
  end

  test "returns existing result when customer message was already handled" do
    conversation = Conversation.create!(customer: customers(:one), status: "waiting_on_bot")
    customer_message = conversation.publish_customer_message!(body: "Where is my order?", customer: customers(:one))
    first_result = BotOrchestrator.call(conversation: conversation, message: customer_message)
    provider = Class.new do
      def call(_request)
        raise "provider should not be called for handled messages"
      end
    end.new

    assert_no_difference("ResponseDraft.count") do
      assert_no_difference("Message.support_messages.count") do
        assert_no_difference("ResponseReview.count") do
          assert_no_difference("RetrievalResult.count") do
            assert_no_difference("AgentDecisionTrace.count") do
              second_result = BotOrchestrator.call(conversation: conversation, message: customer_message, provider: provider)

              assert_equal first_result.response_draft, second_result.response_draft
              assert_equal first_result.message, second_result.message
              assert_equal first_result.agent_decision_trace, second_result.agent_decision_trace
              assert second_result.published?
            end
          end
        end
      end
    end
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
    assert_equal "upload_requested", result.agent_decision_trace.outcome
    assert_equal "image", result.agent_decision_trace.metadata_hash["upload_type"]
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
    assert_equal "low_confidence", result.escalation.reason
    assert_equal result.response_review, result.escalation.response_review
  end

  test "direct human request gets one more bot attempt before escalation" do
    provider = Class.new do
      def call(_request)
        raise "provider should not be called for the one-more-attempt handoff path"
      end
    end.new
    conversation = Conversation.create!(customer: customers(:one), status: "waiting_on_bot")
    customer_message = conversation.publish_customer_message!(body: "human please", customer: customers(:one))

    result = BotOrchestrator.call(conversation: conversation, message: customer_message, provider: provider)

    assert result.published?
    assert_nil result.escalation
    assert_match "We can help here first", result.message.body
    assert_equal "handoff_retry", result.response_draft.category
    assert_equal "answered_directly", result.agent_decision_trace.outcome
    assert_equal "waiting_on_customer", conversation.reload.status
  end

  test "repeated human request creates escalation" do
    provider = Class.new do
      def call(_request)
        raise "provider should not be called for repeated handoff escalation"
      end
    end.new
    conversation = Conversation.create!(customer: customers(:one), status: "waiting_on_bot")
    first_message = conversation.publish_customer_message!(body: "human please", customer: customers(:one))
    BotOrchestrator.call(conversation: conversation, message: first_message, provider: provider)
    second_message = conversation.publish_customer_message!(body: "I still need a human", customer: customers(:one))

    result = BotOrchestrator.call(conversation: conversation, message: second_message, provider: provider)

    assert result.pending_review?
    assert_equal "repeated_handoff_request", result.escalation.reason
    assert_equal "pending_operator_review", conversation.reload.status
    assert_equal "human_review_requested", result.agent_decision_trace.outcome
    assert_no_match(/operator|agent|human/i, result.response_draft.body)
  end

  test "high risk issue escalates immediately without one more attempt" do
    provider = Class.new do
      def call(_request)
        raise "provider should not be called for high risk escalation"
      end
    end.new
    conversation = Conversation.create!(customer: customers(:one), status: "waiting_on_bot")
    customer_message = conversation.publish_customer_message!(body: "This is fraud and an identity issue", customer: customers(:one))

    result = BotOrchestrator.call(conversation: conversation, message: customer_message, provider: provider)

    assert result.pending_review?
    assert_equal "high_risk", result.escalation.reason
    assert_equal "High-risk support issue requires human review.", result.escalation.summary
    assert_equal "pending_operator_review", conversation.reload.status
    assert_equal "human_review_requested", result.agent_decision_trace.outcome
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
    assert_equal "No active bot agent is configured.", result.response_draft.metadata_hash["failure_reason"]
    assert_equal "Automatic response generation failed; review the fallback before replying.", result.response_review.summary
    assert_no_match(/operator|agent|human/i, result.response_draft.body)
    assert_equal "fallback", result.agent_decision_trace.outcome
    assert_equal "No active bot agent is configured.", result.agent_decision_trace.metadata_hash["failure_reason"]
    assert result.agent_decision_trace.review_required?
  end

  test "records provider failures in draft metadata for operator recovery" do
    provider = Class.new do
      def call(_request)
        SupportBot::ProviderResponse.failure("Provider timed out.", raw_provider_response: "timeout")
      end
    end.new
    conversation = Conversation.create!(customer: customers(:one), status: "waiting_on_bot")
    customer_message = conversation.publish_customer_message!(body: "Where is my order?", customer: customers(:one))

    result = BotOrchestrator.call(conversation: conversation, message: customer_message, provider: provider)

    assert_not result.published?
    assert result.pending_review?
    assert_equal "Provider timed out.", result.response_draft.metadata_hash["failure_reason"]
    assert_equal "Automatic response generation failed; review the fallback before replying.", result.response_review.summary
    assert_equal "pending_operator_review", conversation.reload.status
    assert_equal "fallback", result.agent_decision_trace.outcome
    assert_equal "Provider timed out.", result.agent_decision_trace.metadata_hash["failure_reason"]
    assert_equal "provider_failure", result.escalation.reason
  end

  test "records retrieval no-match metadata for operator review" do
    provider = Class.new do
      def call(_request)
        SupportBot::ProviderResponse.new(
          body: "We need to review the policy coverage for this request.",
          confidence: 64,
          category: "general_support",
          status: "pending_review",
          review_reason: "Confidence is below the configured threshold.",
          upload_requested: false,
          source_references: [],
          escalation_recommended: true,
          escalation_reason: "No matching policy context.",
          raw_provider_response: "provider_payload"
        )
      end
    end.new
    conversation = Conversation.create!(customer: customers(:one), status: "waiting_on_bot")
    customer_message = conversation.publish_customer_message!(body: "How do loyalty points work?", customer: customers(:one))

    result = BotOrchestrator.call(conversation: conversation, message: customer_message, provider: provider)

    metadata = result.response_draft.metadata_hash

    assert result.pending_review?
    assert_empty result.retrieval_results
    assert_equal "no_matches", metadata.dig("retrieval", "status")
    assert_equal 0, metadata.dig("retrieval", "result_count")
    assert_equal "How do loyalty points work?", metadata.dig("retrieval", "query")
    assert_equal "No matching knowledge document was found; review the proposed response for policy coverage.", result.response_review.summary
    assert_equal "human_review_requested", result.agent_decision_trace.outcome
    assert_equal "no_matches", result.agent_decision_trace.metadata_hash.dig("retrieval", "status")
  end

  test "uses an injected provider response" do
    provider = Class.new do
      def call(request)
        SupportBot::ProviderResponse.new(
          body: "Provider-generated support reply.",
          confidence: 91,
          category: "provider_test",
          status: "draft",
          upload_requested: false,
          source_references: [],
          escalation_recommended: false,
          raw_provider_response: "provider_payload"
        )
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

  test "records proposed sensitive actions and routes to operator review" do
    provider = Class.new do
      def call(request)
        SupportBot::ProviderResponse.new(
          body: "We've noted this request for review.",
          confidence: 50,
          category: "action_proposal",
          status: "pending_review",
          review_reason: "Proposed refund requires operator review.",
          upload_requested: false,
          source_references: [],
          escalation_recommended: true,
          escalation_reason: "Proposed refund requires operator review.",
          proposed_actions: [
            { action_type: "refund", name: "propose_refund", arguments: { "reason" => "Damaged on arrival", "order_reference" => "A123" } }
          ],
          raw_provider_response: "provider_payload"
        )
      end
    end.new
    conversation = Conversation.create!(customer: customers(:one), status: "waiting_on_bot")
    customer_message = conversation.publish_customer_message!(body: "Refund please", customer: customers(:one))

    result = BotOrchestrator.call(conversation: conversation, message: customer_message, provider: provider)

    assert result.pending_review?
    assert_equal "refund", result.response_draft.proposed_action_type
    assert_equal 1, conversation.support_actions.proposed.count

    action = conversation.support_actions.proposed.first
    assert_equal "refund", action.action_type
    assert_equal "Damaged on arrival", action.eligibility_reason
    assert_equal result.response_review, action.response_review
    assert_equal "action_proposed", result.agent_decision_trace.outcome
    assert_equal [ "propose_refund" ], result.agent_decision_trace.proposed_tools
    assert_equal [ "refund" ], result.agent_decision_trace.proposed_actions
    assert_equal "action_requires_review", result.escalation.reason
  end

  test "forces review and persists proposed actions even on a high-confidence draft response" do
    provider = Class.new do
      def call(request)
        SupportBot::ProviderResponse.new(
          body: "Sure, we can refund that.",
          confidence: 95,
          category: "general_support",
          status: "draft",
          upload_requested: false,
          source_references: [],
          escalation_recommended: false,
          proposed_actions: [ { action_type: "refund", name: "propose_refund", arguments: { "reason" => "Late delivery" } } ],
          raw_provider_response: "provider_payload"
        )
      end
    end.new
    conversation = Conversation.create!(customer: customers(:one), status: "waiting_on_bot")
    customer_message = conversation.publish_customer_message!(body: "Refund please", customer: customers(:one))

    result = BotOrchestrator.call(conversation: conversation, message: customer_message, provider: provider)

    assert_not result.published?, "a proposed sensitive action must never auto-publish"
    assert result.pending_review?
    assert_equal 1, conversation.support_actions.proposed.count
    assert_equal "refund", conversation.support_actions.proposed.first.action_type
  end

  test "wires real LlmProvider tool proposals through to persisted support actions" do
    client = Class.new do
      def initialize(response)
        @response = response
      end

      def post_json(url:, api_key:, payload:)
        @response
      end
    end.new(
      "_http_status" => 200,
      "choices" => [
        {
          "message" => {
            "content" => nil,
            "tool_calls" => [
              {
                "id" => "call_1",
                "type" => "function",
                "function" => { "name" => "propose_refund", "arguments" => JSON.generate("reason" => "Damaged on arrival") }
              }
            ]
          }
        }
      ]
    )
    config = SupportBot::ProviderConfig::Profile.new(name: "openai_compatible", api_key: "k", base_url: "https://example.test/v1", model: "demo/model")
    provider = SupportBot::LlmProvider.new(config: config, client: client)
    conversation = Conversation.create!(customer: customers(:one), status: "waiting_on_bot")
    customer_message = conversation.publish_customer_message!(body: "My order arrived damaged.", customer: customers(:one))

    result = BotOrchestrator.call(conversation: conversation, message: customer_message, provider: provider)

    assert result.pending_review?
    action = conversation.support_actions.proposed.first
    assert_equal "refund", action.action_type
    assert_equal "Damaged on arrival", action.eligibility_reason
  end

  test "persists only known action types from proposed actions" do
    provider = Class.new do
      def call(request)
        SupportBot::ProviderResponse.new(
          body: "We've noted this for review.",
          confidence: 50,
          category: "action_proposal",
          status: "pending_review",
          review_reason: "Mixed proposals require review.",
          upload_requested: false,
          source_references: [],
          escalation_recommended: true,
          escalation_reason: "Mixed proposals require review.",
          proposed_actions: [
            { action_type: "refund", name: "propose_refund", arguments: { "reason" => "Damaged" } },
            { action_type: "teleport", name: "propose_teleport", arguments: { "reason" => "Bogus" } }
          ],
          raw_provider_response: "provider_payload"
        )
      end
    end.new
    conversation = Conversation.create!(customer: customers(:one), status: "waiting_on_bot")
    customer_message = conversation.publish_customer_message!(body: "Refund please", customer: customers(:one))

    BotOrchestrator.call(conversation: conversation, message: customer_message, provider: provider)

    assert_equal %w[refund], conversation.support_actions.proposed.pluck(:action_type)
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
