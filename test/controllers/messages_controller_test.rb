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

  test "conversation page subscribes to live conversation updates" do
    conversation = conversations(:open_conversation)

    get conversation_url(conversation.public_id)

    assert_response :success
    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']"
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(conversation, :messages)}"
    assert_select "div##{ActionView::RecordIdentifier.dom_id(conversation, :customer_status)}"
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

  test "damaged item message can produce a dynamic upload request" do
    conversation = Conversation.create!(customer: customers(:one), status: "open")

    perform_enqueued_jobs(only: BotResponseJob) do
      post conversation_messages_url(conversation.public_id), params: {
        message: { body: "My item arrived damaged and broken." }
      }
    end

    draft = conversation.response_drafts.order(:created_at).last
    support_message = conversation.messages.support_messages.order(:position).last

    assert_redirected_to conversation_url(conversation.public_id)
    assert draft.upload_requested?
    assert_equal "image", draft.upload_type
    assert_match "upload", support_message.body
    assert_equal "waiting_on_customer", conversation.reload.status
  end

  test "conversation renders upload control only for the latest support upload request" do
    conversation = Conversation.create!(customer: customers(:one), status: "open")
    request_draft = conversation.response_drafts.create!(
      bot_agent: bot_agents(:support_bot),
      body: "Please upload an image.",
      status: "published",
      confidence: 88,
      category: "damaged_item",
      upload_requested: true,
      upload_type: "image"
    )
    request_message = conversation.publish_support_message!(
      body: request_draft.body,
      origin: "bot_auto_sent",
      author: bot_agents(:support_bot),
      published_by: bot_agents(:support_bot),
      response_draft: request_draft
    )

    get conversation_url(conversation.public_id)

    assert_response :success
    assert_select "form[action='#{conversation_message_uploads_path(conversation.public_id, request_message)}']"
    assert_select "input[type='file'][accept*='image/png']"
    assert_select "p", text: "Requested file: Image"

    follow_up_draft = conversation.response_drafts.create!(
      bot_agent: bot_agents(:support_bot),
      body: "We can continue without an upload.",
      status: "published",
      confidence: 90,
      category: "damaged_item",
      upload_requested: false
    )
    conversation.publish_support_message!(
      body: follow_up_draft.body,
      origin: "bot_auto_sent",
      author: bot_agents(:support_bot),
      published_by: bot_agents(:support_bot),
      response_draft: follow_up_draft
    )

    get conversation_url(conversation.public_id)

    assert_response :success
    assert_select "form[action='#{conversation_message_uploads_path(conversation.public_id, request_message)}']", count: 0
    assert_select "input[type='file']", count: 0
  end

  test "conversation shows upload success state instead of another upload control" do
    conversation = Conversation.create!(customer: customers(:one), status: "open")
    draft = conversation.response_drafts.create!(
      bot_agent: bot_agents(:support_bot),
      body: "Please upload a document.",
      status: "published",
      confidence: 88,
      category: "returns",
      upload_requested: true,
      upload_type: "document"
    )
    request_message = conversation.publish_support_message!(
      body: draft.body,
      origin: "bot_auto_sent",
      author: bot_agents(:support_bot),
      published_by: bot_agents(:support_bot),
      response_draft: draft
    )
    upload = conversation.uploads.create!(message: request_message, file_type: "document", processing_status: "pending")
    upload.file.attach(
      io: StringIO.new("receipt"),
      filename: "receipt.txt",
      content_type: "text/plain"
    )

    get conversation_url(conversation.public_id)

    assert_response :success
    assert_select "p", text: "Upload received"
    assert_select "p", text: "receipt.txt"
    assert_select "input[type='file']", count: 0
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
