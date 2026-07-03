require "test_helper"

class OperatorMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_operator
  end

  test "operator can publish a direct support reply" do
    conversation = conversations(:open_conversation)
    operator = OperatorUser.order(:email).first

    assert_difference("Message.count", 1) do
      post operator_conversation_messages_url(conversation.public_id), params: {
        message: { body: "We checked the order and it is out for delivery." }
      }
    end

    message = Message.order(:created_at).last
    assert_equal "support", message.public_role
    assert_equal "operator_direct", message.origin
    assert_equal operator, message.author
    assert_equal operator, message.published_by
    assert_equal "waiting_on_customer", conversation.reload.status
    assert_redirected_to operator_conversation_url(conversation.public_id)
  end
end
