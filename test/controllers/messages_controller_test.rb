require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  test "conversation page shows messages in chronological order" do
    conversation = conversations(:open_conversation)

    get conversation_url(conversation.public_id)

    assert_response :success
    first_message_position = response.body.index(messages(:user_message).body)
    second_message_position = response.body.index(messages(:support_message).body)

    assert first_message_position, "Expected the first message body to render"
    assert second_message_position, "Expected the second message body to render"
    assert_operator first_message_position, :<, second_message_position
  end

  test "creates a customer message at the next position" do
    conversation = conversations(:open_conversation)

    assert_difference("conversation.messages.count", 1) do
      post conversation_messages_url(conversation.public_id), params: {
        message: { body: "The tracking page has not updated." }
      }
    end

    message = conversation.messages.order(:position).last

    assert_redirected_to conversation_url(conversation.public_id)
    assert_equal "The tracking page has not updated.", message.body
    assert_equal "customer", message.public_role
    assert_equal "customer_submitted", message.origin
    assert_equal 3, message.position
  end

  test "conversation page includes new message after submission" do
    conversation = conversations(:open_conversation)

    post conversation_messages_url(conversation.public_id), params: {
      message: { body: "Can we change the delivery address?" }
    }
    follow_redirect!

    assert_response :success
    assert_includes response.body, "Can we change the delivery address?"
  end

  test "rejects blank messages" do
    conversation = conversations(:open_conversation)

    assert_no_difference("conversation.messages.count") do
      post conversation_messages_url(conversation.public_id), params: {
        message: { body: "   " }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Body can&#39;t be blank"
  end
end
