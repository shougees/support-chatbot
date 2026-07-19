require "test_helper"

class SupportAnalyticsSnapshotTest < ActiveSupport::TestCase
  test "calculates conversation escalation feedback and category metrics" do
    conversation = conversations(:pending_operator_review_conversation)
    Escalation.create!(
      conversation: conversation,
      status: "pending",
      reason: "low_confidence",
      summary: "Response confidence is below the configured threshold."
    )
    support_message = conversation.publish_support_message!(
      body: "We can help with the next step.",
      origin: "operator_direct",
      author: operator_users(:alice),
      published_by: operator_users(:alice)
    )
    Feedback.create!(message: support_message, rating: "not_helpful")
    conversation.response_drafts.create!(
      bot_agent: bot_agents(:support_bot),
      body: "Refund guidance.",
      status: "published",
      confidence: 80,
      category: "refund"
    )

    snapshot = SupportAnalyticsSnapshot.call

    assert_equal Conversation.count, snapshot.total_conversations
    assert_equal 1, snapshot.escalated_conversations
    assert_equal (1.fdiv(Conversation.count) * 100).round(1), snapshot.escalation_rate
    assert_equal 2, snapshot.feedback_responses
    assert_equal 50.0, snapshot.helpfulness_rate
    assert_equal [ "refund", 2 ], snapshot.top_categories.first
  end

  test "attention list includes unresolved and closed low confidence conversations" do
    unresolved = conversations(:open_conversation)
    low_confidence_closed = conversations(:resolved_conversation)
    low_confidence_closed.response_drafts.create!(
      bot_agent: bot_agents(:support_bot),
      body: "Low-confidence closed response.",
      status: "published",
      confidence: 45,
      category: "delivery"
    )

    attention_conversations = SupportAnalyticsSnapshot.call.attention_conversations

    assert_includes attention_conversations, unresolved
    assert_includes attention_conversations, low_confidence_closed
  end

  test "rates are unavailable when denominators are zero" do
    Conversation.destroy_all

    snapshot = SupportAnalyticsSnapshot.call

    assert_nil snapshot.escalation_rate
    assert_nil snapshot.helpfulness_rate
  end
end
