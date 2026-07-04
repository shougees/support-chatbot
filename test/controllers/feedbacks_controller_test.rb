require "test_helper"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  test "customer can mark a support response helpful" do
    conversation = conversations(:pending_operator_review_conversation)
    message = messages(:second_support_message)

    assert_difference("Feedback.count", 1) do
      post conversation_message_feedback_url(conversation.public_id, message), params: {
        feedback: {
          rating: "helpful",
          note: "This answered my question."
        }
      }
    end

    feedback = message.feedbacks.last

    assert_equal "helpful", feedback.rating
    assert_equal "This answered my question.", feedback.note
    assert_redirected_to conversation_url(conversation.public_id)
  end

  test "customer can update existing feedback for the same support response" do
    conversation = conversations(:open_conversation)
    message = messages(:support_message)

    assert_no_difference("Feedback.count") do
      post conversation_message_feedback_url(conversation.public_id, message), params: {
        feedback: {
          rating: "not_helpful",
          note: "We still need tracking details."
        }
      }
    end

    feedback = feedbacks(:helpful_response).reload

    assert_equal "not_helpful", feedback.rating
    assert_equal "We still need tracking details.", feedback.note
    assert_redirected_to conversation_url(conversation.public_id)
  end

  test "customer cannot leave feedback on their own message" do
    conversation = conversations(:open_conversation)
    message = messages(:user_message)

    assert_no_difference("Feedback.count") do
      post conversation_message_feedback_url(conversation.public_id, message), params: {
        feedback: {
          rating: "helpful"
        }
      }
    end

    assert_response :not_found
  end

  test "invalid feedback redirects without creating a record" do
    conversation = conversations(:pending_operator_review_conversation)
    message = messages(:second_support_message)

    assert_no_difference("Feedback.count") do
      post conversation_message_feedback_url(conversation.public_id, message), params: {
        feedback: {
          rating: "neutral"
        }
      }
    end

    assert_redirected_to conversation_url(conversation.public_id)
  end
end
