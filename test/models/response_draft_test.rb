require "test_helper"

class ResponseDraftTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "valid with required fields" do
    draft = ResponseDraft.new(
      conversation: conversations(:open_conversation),
      bot_agent: bot_agents(:support_bot),
      body: "We can help with that.",
      status: "draft",
      confidence: 72.5
    )

    assert draft.valid?
  end

  test "belongs to conversation and optional bot agent" do
    draft = response_drafts(:standard_response)

    assert_equal conversations(:open_conversation), draft.conversation
    assert_equal bot_agents(:support_bot), draft.bot_agent
  end

  test "can link to a published support message" do
    assert_equal messages(:support_message), response_drafts(:standard_response).published_message
  end

  test "has response reviews" do
    assert_includes response_drafts(:review_recommended_response).response_reviews, response_reviews(:refund_review)
  end

  test "requires body" do
    draft = response_drafts(:standard_response)
    draft.body = nil

    assert_not draft.valid?
    assert_includes draft.errors[:body], "can't be blank"
  end

  test "requires valid status" do
    draft = response_drafts(:standard_response)
    draft.status = "waiting"

    assert_not draft.valid?
    assert_includes draft.errors[:status], "is not included in the list"
  end

  test "requires confidence between zero and one hundred" do
    draft = response_drafts(:standard_response)
    draft.confidence = 101

    assert_not draft.valid?
    assert_includes draft.errors[:confidence], "must be less than or equal to 100"
  end

  test "upload type must be valid when present" do
    draft = response_drafts(:review_recommended_response)
    draft.upload_type = "spreadsheet"

    assert_not draft.valid?
    assert_includes draft.errors[:upload_type], "is not included in the list"
  end

  test "low confidence scope uses configurable threshold" do
    assert_includes ResponseDraft.low_confidence(70), response_drafts(:review_recommended_response)
    assert_not ResponseDraft.low_confidence(70).include?(response_drafts(:standard_response))
  end

  test "approving a draft publishes a support message with audit provenance" do
    conversation = Conversation.create!(customer: customers(:one), status: "pending_operator_review")
    draft = ResponseDraft.create!(
      conversation: conversation,
      bot_agent: bot_agents(:support_bot),
      body: "We can help with that.",
      status: "pending_review",
      confidence: 68
    )
    ResponseReview.create!(
      conversation: conversation,
      response_draft: draft,
      key_decision: "response_publication"
    )

    message = draft.publish_approved!(operator_user: operator_users(:alice))

    assert_equal "support", message.public_role
    assert_equal "bot_approved", message.origin
    assert_equal bot_agents(:support_bot), message.author
    assert_equal operator_users(:alice), message.published_by
    assert_equal "published", draft.reload.status
    assert_equal "approved", draft.response_reviews.first.status
    assert_equal "waiting_on_customer", conversation.reload.status
  end

  test "pending review scope returns draft responses awaiting review" do
    assert_equal [ response_drafts(:review_recommended_response) ], ResponseDraft.pending_review.to_a
  end

  test "response drafts can render live operator broadcasts" do
    conversation = Conversation.create!(customer: customers(:one), status: "pending_operator_review")

    assert_nothing_raised do
      perform_enqueued_jobs(only: Turbo::Streams::ActionBroadcastJob) do
        ResponseDraft.create!(
          conversation: conversation,
          bot_agent: bot_agents(:support_bot),
          body: "We can help review this request.",
          status: "pending_review",
          confidence: 64,
          category: "order_support"
        )
      end
    end
  end
end
