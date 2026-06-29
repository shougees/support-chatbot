require "test_helper"

class AgentDecisionTraceTest < ActiveSupport::TestCase
  test "valid with required fields" do
    trace = AgentDecisionTrace.new(
      conversation: conversations(:open_conversation),
      message: messages(:user_message),
      outcome: "answered_directly"
    )

    assert trace.valid?
  end

  test "requires valid outcome" do
    trace = AgentDecisionTrace.new(
      conversation: conversations(:open_conversation),
      message: messages(:user_message),
      outcome: "thinking"
    )

    assert_not trace.valid?
    assert_includes trace.errors[:outcome], "is not included in the list"
  end

  test "requires message to belong to conversation" do
    trace = AgentDecisionTrace.new(
      conversation: conversations(:pending_operator_review_conversation),
      message: messages(:user_message),
      outcome: "answered_directly"
    )

    assert_not trace.valid?
    assert_includes trace.errors[:message], "must belong to conversation"
  end

  test "parses structured arrays and metadata safely" do
    trace = AgentDecisionTrace.new(
      conversation: conversations(:open_conversation),
      message: messages(:user_message),
      outcome: "action_proposed",
      retrieved_knowledge_document_ids: [ knowledge_documents(:refund_policy).id ].to_json,
      proposed_tool_names: [ "propose_refund" ].to_json,
      proposed_action_types: [ "refund" ].to_json,
      metadata: { "failure_reason" => "Provider timed out." }.to_json
    )

    assert_equal [ knowledge_documents(:refund_policy).id ], trace.retrieved_document_ids
    assert_equal [ "propose_refund" ], trace.proposed_tools
    assert_equal [ "refund" ], trace.proposed_actions
    assert_equal "Provider timed out.", trace.metadata_hash["failure_reason"]

    trace.metadata = "{bad json"
    trace.proposed_tool_names = "{bad json"

    assert_equal({}, trace.metadata_hash)
    assert_equal [], trace.proposed_tools
  end
end
