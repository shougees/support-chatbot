require "test_helper"

class ConversationsControllerTest < ActionDispatch::IntegrationTest
  test "creates a conversation with open status" do
    assert_difference("Conversation.count", 1) do
      post conversations_url
    end

    conversation = Conversation.order(:created_at).last
    assert_equal "open", conversation.status
    assert_not_nil conversation.public_id
    assert_redirected_to conversation_url(conversation.public_id)
  end

  test "shows a conversation by public id" do
    conversation = conversations(:open_conversation)

    get conversation_url(conversation.public_id)

    assert_response :success
    assert_match conversation.public_id, @response.body
    assert_match conversation.status, @response.body
  end
end
