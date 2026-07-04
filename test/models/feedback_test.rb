require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  test "valid with required fields" do
    feedback = Feedback.new(message: messages(:second_support_message), rating: "helpful")

    assert feedback.valid?
  end

  test "belongs to support message" do
    feedback = feedbacks(:helpful_response)

    assert_equal messages(:support_message), feedback.message
  end

  test "requires valid rating" do
    feedback = feedbacks(:helpful_response)
    feedback.rating = "neutral"

    assert_not feedback.valid?
    assert_includes feedback.errors[:rating], "is not included in the list"
  end

  test "requires support message" do
    feedback = Feedback.new(message: messages(:user_message), rating: "helpful")

    assert_not feedback.valid?
    assert_includes feedback.errors[:message], "must be a support message"
  end

  test "allows one feedback per support message" do
    feedback = Feedback.new(message: messages(:support_message), rating: "not_helpful")

    assert_not feedback.valid?
    assert_includes feedback.errors[:message_id], "has already been taken"
  end

  test "limits note length" do
    feedback = Feedback.new(message: messages(:second_support_message), rating: "helpful", note: "a" * 501)

    assert_not feedback.valid?
    assert_includes feedback.errors[:note], "is too long (maximum is 500 characters)"
  end
end
