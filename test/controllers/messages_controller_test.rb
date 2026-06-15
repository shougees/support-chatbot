require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  test "customer can publish a message into a public conversation" do
    conversation = conversations(:open_conversation)

    assert_difference("Message.count", 1) do
      post conversation_messages_url(conversation.public_id), params: {
        message: { body: "My package arrived damaged." }
      }
    end

    message = Message.order(:created_at).last
    assert_equal conversation, message.conversation
    assert_equal "customer", message.public_role
    assert_equal "customer_submitted", message.origin
    assert_equal "My package arrived damaged.", message.body
    assert_redirected_to conversation_url(conversation.public_id)
    assert_equal "waiting_on_bot", conversation.reload.status
  end

  test "blank customer message is rejected" do
    conversation = conversations(:open_conversation)

    assert_no_difference("Message.count") do
      post conversation_messages_url(conversation.public_id), params: {
        message: { body: "" }
      }
    end

    assert_response :unprocessable_entity
    assert_match /Body can.*blank/, @response.body
  end
end
