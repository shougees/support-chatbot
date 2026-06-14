require "test_helper"

class HumanReviewTest < ActiveSupport::TestCase
  test "valid with required fields" do
    review = HumanReview.new(
      conversation: conversations(:open_conversation),
      status: "open",
      key_decision: "refund_eligibility"
    )

    assert review.valid?
  end

  test "belongs to conversation and optional message and operator user" do
    review = human_reviews(:refund_review)

    assert_equal conversations(:pending_human_review_conversation), review.conversation
    assert_equal messages(:second_assistant_message), review.message
    assert_equal operator_users(:alice), review.operator_user
  end

  test "has support actions" do
    assert_includes human_reviews(:refund_review).support_actions, support_actions(:proposed_refund)
  end

  test "requires key decision" do
    review = human_reviews(:refund_review)
    review.key_decision = nil

    assert_not review.valid?
    assert_includes review.errors[:key_decision], "can't be blank"
  end

  test "requires valid status" do
    review = human_reviews(:refund_review)
    review.status = "waiting"

    assert_not review.valid?
    assert_includes review.errors[:status], "is not included in the list"
  end

  test "confidence must be between zero and one hundred when present" do
    review = human_reviews(:refund_review)
    review.confidence = -1

    assert_not review.valid?
    assert_includes review.errors[:confidence], "must be greater than or equal to 0"
  end

  test "open, in review, and resolved scopes categorize reviews" do
    assert_includes HumanReview.in_review, human_reviews(:refund_review)
    assert_empty HumanReview.open.where(id: human_reviews(:refund_review).id)
    assert_empty HumanReview.resolved.where(id: human_reviews(:refund_review).id)
  end
end
