require "test_helper"

class UploadsControllerTest < ActionDispatch::IntegrationTest
  test "customer can upload a requested document" do
    conversation, request_message = create_upload_request(upload_type: "document")

    assert_difference("Upload.count", 1) do
      post conversation_message_uploads_url(conversation.public_id, request_message), params: {
        upload: {
          file: fixture_file_upload("receipt.txt", "text/plain")
        }
      }
    end

    upload = Upload.order(:created_at).last

    assert_redirected_to conversation_url(conversation.public_id)
    assert_equal "Upload received.", flash[:notice]
    assert_equal conversation, upload.conversation
    assert_equal request_message, upload.message
    assert_equal "document", upload.file_type
    assert upload.file.attached?
  end

  test "customer sees a clear error when requested file type is invalid" do
    conversation, request_message = create_upload_request(upload_type: "image")

    assert_no_difference("Upload.count") do
      post conversation_message_uploads_url(conversation.public_id, request_message), params: {
        upload: {
          file: fixture_file_upload("receipt.txt", "text/plain")
        }
      }
    end

    assert_redirected_to conversation_url(conversation.public_id)
    assert_match "File must be an image", flash[:alert]
  end

  test "customer sees a clear error when no file is selected" do
    conversation, request_message = create_upload_request(upload_type: "either")

    assert_no_difference("Upload.count") do
      post conversation_message_uploads_url(conversation.public_id, request_message), params: { upload: {} }
    end

    assert_redirected_to conversation_url(conversation.public_id)
    assert_equal "Choose a file to upload.", flash[:alert]
  end

  test "upload endpoint is unavailable when support did not request a file" do
    conversation, support_message = create_support_message(upload_requested: false)

    post conversation_message_uploads_url(conversation.public_id, support_message), params: {
      upload: {
        file: fixture_file_upload("receipt.txt", "text/plain")
      }
    }

    assert_response :not_found
  end

  test "stale upload request is unavailable after a newer support reply" do
    conversation, request_message = create_upload_request(upload_type: "image")
    follow_up_draft = conversation.response_drafts.create!(
      bot_agent: bot_agents(:support_bot),
      body: "We can continue without a file.",
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

    assert_no_difference("Upload.count") do
      post conversation_message_uploads_url(conversation.public_id, request_message), params: {
        upload: {
          file: fixture_file_upload("receipt.txt", "text/plain")
        }
      }
    end

    assert_response :not_found
  end

  private

  def create_upload_request(upload_type:)
    create_support_message(upload_requested: true, upload_type: upload_type)
  end

  def create_support_message(upload_requested:, upload_type: nil)
    conversation = Conversation.create!(customer: customers(:one), status: "open")
    draft = conversation.response_drafts.create!(
      bot_agent: bot_agents(:support_bot),
      body: "Please upload the requested evidence.",
      status: "published",
      confidence: 88,
      category: "damaged_item",
      upload_requested: upload_requested,
      upload_type: upload_type
    )
    message = conversation.publish_support_message!(
      body: draft.body,
      origin: "bot_auto_sent",
      author: bot_agents(:support_bot),
      published_by: bot_agents(:support_bot),
      response_draft: draft
    )

    [ conversation, message ]
  end
end
