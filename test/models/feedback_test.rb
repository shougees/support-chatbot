require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  test "valid with required fields" do
    feedback = Feedback.new(message: messages(:assistant_message), rating: "helpful")

    assert feedback.valid?
  end

  test "belongs to assistant message" do
    feedback = feedbacks(:helpful_response)

    assert_equal messages(:assistant_message), feedback.message
  end

  test "requires valid rating" do
    feedback = feedbacks(:helpful_response)
    feedback.rating = "neutral"

    assert_not feedback.valid?
    assert_includes feedback.errors[:rating], "is not included in the list"
  end

  test "requires assistant message" do
    feedback = Feedback.new(message: messages(:user_message), rating: "helpful")

    assert_not feedback.valid?
    assert_includes feedback.errors[:message], "must be an assistant message"
  end
end
