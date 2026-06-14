require "test_helper"

class ResponseReviewTest < ActiveSupport::TestCase
  test "valid with required fields" do
    review = ResponseReview.new(
      conversation: conversations(:open_conversation),
      response_draft: response_drafts(:standard_response),
      status: "pending",
      key_decision: "refund_eligibility"
    )

    assert review.valid?
  end

  test "belongs to conversation, draft, optional message, and optional operator user" do
    review = response_reviews(:refund_review)

    assert_equal conversations(:pending_operator_review_conversation), review.conversation
    assert_equal messages(:second_support_message), review.message
    assert_equal response_drafts(:review_recommended_response), review.response_draft
    assert_equal operator_users(:alice), review.operator_user
  end

  test "has support actions" do
    assert_includes response_reviews(:refund_review).support_actions, support_actions(:proposed_refund)
  end

  test "requires key decision" do
    review = response_reviews(:refund_review)
    review.key_decision = nil

    assert_not review.valid?
    assert_includes review.errors[:key_decision], "can't be blank"
  end

  test "requires valid status" do
    review = response_reviews(:refund_review)
    review.status = "waiting"

    assert_not review.valid?
    assert_includes review.errors[:status], "is not included in the list"
  end

  test "pending, approved, rejected, and resolved scopes categorize reviews" do
    assert_includes ResponseReview.pending, response_reviews(:refund_review)
    assert_empty ResponseReview.approved.where(id: response_reviews(:refund_review).id)
    assert_empty ResponseReview.rejected.where(id: response_reviews(:refund_review).id)
    assert_empty ResponseReview.resolved.where(id: response_reviews(:refund_review).id)
  end
end
