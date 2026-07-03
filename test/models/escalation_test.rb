require "test_helper"

class EscalationTest < ActiveSupport::TestCase
  test "valid with required fields" do
    escalation = Escalation.new(
      conversation: conversations(:pending_operator_review_conversation),
      message: messages(:second_support_message),
      status: "pending",
      reason: "low_confidence",
      summary: "Bot confidence is below threshold."
    )

    assert escalation.valid?
  end

  test "requires valid status and reason" do
    escalation = Escalation.new(
      conversation: conversations(:pending_operator_review_conversation),
      status: "waiting",
      reason: "confused",
      summary: "Needs review."
    )

    assert_not escalation.valid?
    assert_includes escalation.errors[:status], "is not included in the list"
    assert_includes escalation.errors[:reason], "is not included in the list"
  end

  test "message and response review must belong to conversation" do
    escalation = Escalation.new(
      conversation: conversations(:open_conversation),
      message: messages(:second_support_message),
      response_review: response_reviews(:refund_review),
      status: "pending",
      reason: "policy_review",
      summary: "Needs review."
    )

    assert_not escalation.valid?
    assert_includes escalation.errors[:message], "must belong to the same conversation"
    assert_includes escalation.errors[:response_review], "must belong to the same conversation"
  end

  test "status updates assign operator and terminal timestamp" do
    escalation = Escalation.create!(
      conversation: conversations(:pending_operator_review_conversation),
      status: "pending",
      reason: "policy_review",
      summary: "Needs review."
    )

    escalation.update_status!(status: "resolved", operator_user: operator_users(:alice))

    assert_equal "resolved", escalation.status
    assert_equal operator_users(:alice), escalation.operator_user
    assert_not_nil escalation.resolved_at
  end

  test "metadata hash falls back for malformed json" do
    escalation = Escalation.new(metadata: { source: "bot" }.to_json)

    assert_equal "bot", escalation.metadata_hash["source"]

    escalation.metadata = "{bad json"

    assert_equal({}, escalation.metadata_hash)
  end
end
