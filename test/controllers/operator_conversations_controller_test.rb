require "test_helper"

class OperatorConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_operator
  end

  test "operator can list conversations for review" do
    messages(:user_message).create_agent_decision_trace!(
      conversation: conversations(:open_conversation),
      bot_agent: bot_agents(:support_bot),
      response_draft: response_drafts(:standard_response),
      published_message: messages(:support_message),
      outcome: "answered_directly",
      provider_name: "openai",
      provider_model: "gpt-4o",
      response_category: "order_status",
      confidence: 86.5
    )

    get operator_conversations_url

    assert_response :success
    assert_select "h1", text: "Conversation review queue"
    assert_select "a[href='#{operator_conversation_path(conversations(:open_conversation).public_id)}']"
    assert_select "p", text: /conv-open-001/
    assert_select "dt", text: "Messages"
    assert_select "dt", text: "Feedback"
    assert_select "dt", text: "Sources"
    assert_select "dt", text: "Uploads"
    assert_select "dd", text: "2", minimum: 1
    assert_select "dd", text: "1", minimum: 2
    assert_select "dd", text: "87%"
  end

  test "operator can visually identify escalated conversations" do
    conversation = conversations(:pending_operator_review_conversation)
    Escalation.create!(
      conversation: conversation,
      message: messages(:second_support_message),
      response_review: response_reviews(:refund_review),
      status: "pending",
      reason: "policy_review",
      summary: "Needs policy review."
    )

    get operator_conversations_url

    assert_response :success
    assert_select "span", text: "Escalated"
    assert_select "p", text: /Policy review:/
    assert_select "p", text: /Needs policy review/
  end

  test "operator can filter to escalated conversations" do
    conversation = conversations(:pending_operator_review_conversation)
    Escalation.create!(
      conversation: conversation,
      message: messages(:second_support_message),
      response_review: response_reviews(:refund_review),
      status: "pending",
      reason: "policy_review",
      summary: "Needs policy review."
    )

    get operator_conversations_url(filter: "escalated")

    assert_response :success
    assert_match conversation.public_id, response.body
    assert_no_match conversations(:open_conversation).public_id, response.body
  end

  test "operator detail links back to review queue" do
    conversation = conversations(:open_conversation)

    get operator_conversation_url(conversation.public_id)

    assert_response :success
    assert_select "a[href='#{operator_conversations_path}']", text: "Review queue"
  end

  test "operator conversation subscribes to live conversation updates" do
    conversation = conversations(:open_conversation)

    get operator_conversation_url(conversation.public_id)

    assert_response :success
    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']"
    assert_select "p##{ActionView::RecordIdentifier.dom_id(conversation, :operator_status)}"
    assert_select "div##{ActionView::RecordIdentifier.dom_id(conversation, :operator_transcript)}"
    assert_select "div##{ActionView::RecordIdentifier.dom_id(conversation, :operator_response_drafts)}"
  end

  test "shows source document titles for messages with retrieval results" do
    get operator_conversation_url(conversations(:open_conversation).public_id)

    assert_response :success
    assert_select "p", text: /Sources/i
    assert_select "li", text: /Refund Policy/
  end

  test "shows feedback and uploads in conversation details" do
    get operator_conversation_url(conversations(:open_conversation).public_id)

    assert_response :success
    assert_select "p", text: "Feedback"
    assert_select "li", text: /Helpful/
    assert_select "li", text: /The answer was clear/
    assert_select "p", text: "Uploads"
    assert_select "li", text: /Image/
    assert_select "li", text: /Completed/
    assert_select "li", text: /Photo appears to show damaged packaging/
  end

  test "shows escalation details and status control" do
    conversation = conversations(:pending_operator_review_conversation)
    Escalation.create!(
      conversation: conversation,
      message: messages(:second_support_message),
      response_review: response_reviews(:refund_review),
      status: "pending",
      reason: "policy_review",
      summary: "Needs policy review."
    )

    get operator_conversation_url(conversation.public_id)

    assert_response :success
    assert_select "h2", text: "Escalations"
    assert_select "p", text: "Policy review"
    assert_select "p", text: "Needs policy review."
    assert_select "select[name='escalation[status]']"
  end

  test "shows agent decision trace in conversation details" do
    message = messages(:user_message)
    message.create_agent_decision_trace!(
      conversation: message.conversation,
      bot_agent: bot_agents(:support_bot),
      response_draft: response_drafts(:standard_response),
      published_message: messages(:support_message),
      outcome: "answered_directly",
      provider_name: "openai",
      provider_model: "gpt-4o",
      response_category: "order_status",
      confidence: 86.5,
      review_required: false,
      retrieved_knowledge_document_ids: [ knowledge_documents(:refund_policy).id ].to_json,
      proposed_tool_names: [ "search_knowledge_base" ].to_json,
      metadata: { retrieval: { status: "matched" } }.to_json
    )

    get operator_conversation_url(message.conversation.public_id)

    assert_response :success
    assert_select "p", text: "Agent decision trace"
    assert_select "dd", text: "Answered directly"
    assert_select "dd", text: "openai / gpt-4o"
    assert_select "dd", text: "order_status"
    assert_select "dd", text: "87%"
    assert_select "dd", text: "Not required"
    assert_select "dd", text: /search_knowledge_base/
  end

  test "operator conversation requires a local operator user" do
    without_operator_users do
      get operator_conversation_url(conversations(:open_conversation).public_id)
    end

    assert_redirected_to root_url
    assert_equal "Create an operator user before using the operator workspace.", flash[:alert]
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

  test "shows fallback and retrieval details for response drafts needing review" do
    conversation = Conversation.create!(customer: customers(:one), status: "pending_operator_review")
    draft = conversation.response_drafts.create!(
      bot_agent: bot_agents(:support_bot),
      body: "We are checking this and will reply here.",
      status: "pending_review",
      confidence: 0,
      category: "fallback",
      review_reason: "Bot response job failed.",
      metadata: {
        failure_reason: "Bot response job failed.",
        job_error: { class: "RuntimeError" },
        retrieval: { status: "no_matches" }
      }.to_json
    )
    draft.response_reviews.create!(
      conversation: conversation,
      status: "pending",
      key_decision: "response_publication",
      reason: "Bot response job failed."
    )

    get operator_conversation_url(conversation.public_id)

    assert_response :success
    assert_select "dt", text: "Fallback:"
    assert_select "dd", text: "Bot response job failed."
    assert_select "dt", text: "Job error:"
    assert_select "dd", text: "RuntimeError"
    assert_select "dt", text: "Retrieval:"
    assert_select "dd", text: "No matching knowledge document found."
  end

  private

  def without_operator_users
    ResponseReview.update_all(operator_user_id: nil)
    Escalation.update_all(operator_user_id: nil)
    OperatorUser.delete_all
    yield
  end
end
