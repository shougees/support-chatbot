require "test_helper"

class SupportActionTest < ActiveSupport::TestCase
  test "valid with required fields" do
    action = SupportAction.new(
      conversation: conversations(:open_conversation),
      action_type: "refund",
      status: "proposed"
    )

    assert action.valid?
  end

  test "belongs to conversation and optional message and human review" do
    action = support_actions(:proposed_refund)

    assert_equal conversations(:pending_human_review_conversation), action.conversation
    assert_equal messages(:second_assistant_message), action.message
    assert_equal human_reviews(:refund_review), action.human_review
  end

  test "requires valid action type" do
    action = support_actions(:proposed_refund)
    action.action_type = "gift_card"

    assert_not action.valid?
    assert_includes action.errors[:action_type], "is not included in the list"
  end

  test "requires valid status" do
    action = support_actions(:proposed_refund)
    action.status = "waiting"

    assert_not action.valid?
    assert_includes action.errors[:status], "is not included in the list"
  end

  test "scopes return matching statuses" do
    assert_includes SupportAction.requires_review, support_actions(:proposed_refund)
    assert_empty SupportAction.proposed.where(id: support_actions(:proposed_refund).id)
  end
end
