require "test_helper"

class OperatorResponseDraftsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @operator = OperatorUser.order(:email).first
  end

  test "operator approves a bot draft and publishes a support message" do
    draft = build_reviewable_draft

    assert_difference("Message.count", 1) do
      post approve_operator_response_draft_url(draft)
    end

    message = Message.order(:created_at).last
    assert_equal "support", message.public_role
    assert_equal "bot_approved", message.origin
    assert_equal draft.bot_agent, message.author
    assert_equal @operator, message.published_by
    assert_equal draft, message.response_draft
    assert_equal "published", draft.reload.status
    assert_equal "waiting_on_customer", draft.conversation.status
    assert_equal "approved", draft.response_reviews.first.status
    assert_redirected_to operator_conversation_url(draft.conversation.public_id)
  end

  test "operator edits a bot draft before publishing" do
    draft = build_reviewable_draft

    post publish_edit_operator_response_draft_url(draft), params: {
      response_draft: { body: "We can send a replacement today." }
    }

    message = Message.order(:created_at).last
    review = draft.response_reviews.first.reload
    assert_equal "support", message.public_role
    assert_equal "bot_edited", message.origin
    assert_equal "We can send a replacement today.", message.body
    assert_equal draft.bot_agent, message.author
    assert_equal @operator, message.published_by
    assert_equal "edited", review.status
    assert_equal "We can send a replacement today.", review.edited_body
  end

  test "operator rejects a bot draft and publishes a replacement" do
    draft = build_reviewable_draft

    post replace_operator_response_draft_url(draft), params: {
      response_draft: { body: "We will replace the damaged item." }
    }

    message = Message.order(:created_at).last
    review = draft.response_reviews.first.reload
    assert_equal "support", message.public_role
    assert_equal "operator_replacement", message.origin
    assert_equal "We will replace the damaged item.", message.body
    assert_equal @operator, message.author
    assert_equal @operator, message.published_by
    assert_equal "rejected", draft.reload.status
    assert_equal "rejected", review.status
    assert_equal "We will replace the damaged item.", review.agent_response
  end

  test "published drafts cannot be published twice" do
    draft = response_drafts(:standard_response)

    assert_no_difference("Message.count") do
      post approve_operator_response_draft_url(draft)
    end

    assert_redirected_to operator_conversation_url(draft.conversation.public_id)
    assert_equal "has already been published", flash[:alert]
  end

  private

  def build_reviewable_draft
    conversation = Conversation.create!(customer: customers(:one), status: "pending_operator_review")
    draft = ResponseDraft.create!(
      conversation: conversation,
      bot_agent: bot_agents(:support_bot),
      body: "We can help with the damaged item.",
      status: "pending_review",
      confidence: 61.5,
      category: "damaged_item",
      review_reason: "Confidence is below the configured threshold."
    )
    ResponseReview.create!(
      conversation: conversation,
      response_draft: draft,
      status: "pending",
      key_decision: "response_publication",
      reason: draft.review_reason
    )
    draft
  end
end
