require "test_helper"

class UploadTest < ActiveSupport::TestCase
  test "valid with required fields" do
    upload = Upload.new(conversation: conversations(:open_conversation), file_type: "image", processing_status: "pending")

    assert upload.valid?
  end

  test "belongs to conversation and optional message" do
    upload = uploads(:damage_photo)

    assert_equal conversations(:open_conversation), upload.conversation
    assert_equal messages(:user_message), upload.message
  end

  test "requires valid file type" do
    upload = uploads(:damage_photo)
    upload.file_type = "audio"

    assert_not upload.valid?
    assert_includes upload.errors[:file_type], "is not included in the list"
  end

  test "requires valid processing status" do
    upload = uploads(:damage_photo)
    upload.processing_status = "unknown"

    assert_not upload.valid?
    assert_includes upload.errors[:processing_status], "is not included in the list"
  end

  test "can attach an image file" do
    upload = Upload.new(conversation: conversations(:open_conversation), message: messages(:user_message), file_type: "image")
    attach_file(upload, content_type: "image/png", filename: "damage.png")

    assert upload.valid?
    assert upload.file.attached?
    assert_equal "image/png", upload.file_content_type
  end

  test "rejects non image content for image uploads" do
    upload = Upload.new(conversation: conversations(:open_conversation), message: messages(:user_message), file_type: "image")
    attach_file(upload, content_type: "application/pdf", filename: "return-label.pdf")

    assert_not upload.valid?
    assert_includes upload.errors[:file], "must be an image"
  end

  test "allows supported document uploads" do
    upload = Upload.new(conversation: conversations(:open_conversation), message: messages(:user_message), file_type: "document")
    attach_file(upload, content_type: "application/pdf", filename: "receipt.pdf")

    assert upload.valid?
  end

  test "rejects unsupported attached file content type" do
    upload = Upload.new(conversation: conversations(:open_conversation), message: messages(:user_message), file_type: "other")
    attach_file(upload, content_type: "application/octet-stream", filename: "archive.bin")

    assert_not upload.valid?
    assert_includes upload.errors[:file], "content type is not supported"
  end

  test "message must belong to the same conversation" do
    other_conversation = Conversation.create!(customer: customers(:one), status: "open")
    upload = Upload.new(conversation: other_conversation, message: messages(:user_message), file_type: "image")

    assert_not upload.valid?
    assert_includes upload.errors[:message], "must belong to the same conversation"
  end

  private

  def attach_file(upload, content_type:, filename:)
    upload.file.attach(
      io: StringIO.new("test file"),
      filename: filename,
      content_type: content_type
    )
  end
end
