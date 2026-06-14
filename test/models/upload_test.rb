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
end
