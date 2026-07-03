require "test_helper"

class OperatorEscalationsControllerTest < ActionDispatch::IntegrationTest
  test "operator updates escalation status" do
    escalation = Escalation.create!(
      conversation: conversations(:pending_operator_review_conversation),
      message: messages(:second_support_message),
      response_review: response_reviews(:refund_review),
      status: "pending",
      reason: "policy_review",
      summary: "Needs policy review."
    )

    patch operator_escalation_url(escalation), params: {
      escalation: { status: "in_progress" }
    }

    assert_redirected_to operator_conversation_url(escalation.conversation.public_id)
    assert_equal "Escalation updated.", flash[:notice]
    assert_equal "in_progress", escalation.reload.status
    assert_equal operator_users(:alice), escalation.operator_user
    assert_nil escalation.resolved_at
  end

  test "operator resolving escalation records resolved timestamp" do
    escalation = Escalation.create!(
      conversation: conversations(:pending_operator_review_conversation),
      status: "pending",
      reason: "low_confidence",
      summary: "Bot confidence is below threshold."
    )

    patch operator_escalation_url(escalation), params: {
      escalation: { status: "resolved" }
    }

    assert_redirected_to operator_conversation_url(escalation.conversation.public_id)
    assert_equal "resolved", escalation.reload.status
    assert_not_nil escalation.resolved_at
  end
end
