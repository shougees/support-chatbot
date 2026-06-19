require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end

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

  test "customer can publish a message into a public conversation" do
    conversation = conversations(:open_conversation)

    assert_enqueued_jobs 1, only: BotResponseJob do
      assert_difference("Message.count", 1) do
        post conversation_messages_url(conversation.public_id), params: {
          message: { body: "My package arrived damaged." }
        }
      end
    end

    message = Message.order(:created_at).last

    assert_equal conversation, message.conversation
    assert_equal "customer", message.public_role
    assert_equal "customer_submitted", message.origin
    assert_equal "My package arrived damaged.", message.body
    assert_redirected_to conversation_url(conversation.public_id)
    assert_equal "waiting_on_bot", conversation.reload.status
  end

  test "customer message enqueue includes the conversation and message" do
    conversation = conversations(:open_conversation)

    post conversation_messages_url(conversation.public_id), params: {
      message: { body: "Where is the order?" }
    }

    message = Message.order(:created_at).last
    assert_enqueued_with(job: BotResponseJob, args: [ conversation, message ])
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
    assert_includes response.body, "We are checking this and will reply here."
  end

  test "blank customer message is rejected" do
    conversation = conversations(:open_conversation)

    assert_no_difference("conversation.messages.count") do
      post conversation_messages_url(conversation.public_id), params: {
        message: { body: "   " }
      }
    end

    assert_response :unprocessable_entity
    assert_match /Body can.*blank/, response.body
    assert_no_enqueued_jobs only: BotResponseJob
  end
end
