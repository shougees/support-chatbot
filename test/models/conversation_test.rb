require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "valid with required fields" do
    conversation = Conversation.new(status: "open")
    assert conversation.valid?
  end

  test "auto-generates public_id before create" do
    conversation = Conversation.create!(status: "open")
    assert_not_nil conversation.public_id
    assert_match(/\A[0-9a-f-]{36}\z/, conversation.public_id)
  end

  test "public_id must be unique" do
    Conversation.create!(public_id: "duplicate-id", status: "open")
    duplicate = Conversation.new(public_id: "duplicate-id", status: "open")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:public_id], "has already been taken"
  end

  test "status is required" do
    conversation = Conversation.new(status: nil)
    conversation.valid?
    assert_includes conversation.errors[:status], "can't be blank"
  end

  test "status must be a valid value" do
    conversation = Conversation.new(status: "invalid_status")
    assert_not conversation.valid?
    assert_includes conversation.errors[:status], "is not included in the list"
  end

  test "accepts all valid statuses" do
    Conversation::STATUSES.each do |status|
      conversation = Conversation.new(status: status)
      assert conversation.valid?, "Expected #{status} to be valid"
    end
  end

  test "has many messages" do
    conversation = conversations(:open_conversation)
    assert_respond_to conversation, :messages
    assert_equal 2, conversation.messages.count
  end

  test "destroying conversation destroys dependent messages" do
    conversation = conversations(:open_conversation)
    assert_difference("Message.count", -conversation.messages.count) do
      conversation.destroy
    end
  end

  test "escalated? returns true when status is escalated" do
    conversation = conversations(:escalated_conversation)
    assert conversation.escalated?
  end

  test "escalated? returns false when status is not escalated" do
    conversation = conversations(:open_conversation)
    assert_not conversation.escalated?
  end

  test "resolved? returns true when status is resolved" do
    conversation = conversations(:resolved_conversation)
    assert conversation.resolved?
  end

  test "open scope returns only open conversations" do
    open_count = Conversation.open.count
    assert open_count >= 1
    Conversation.open.each do |c|
      assert_equal "open", c.status
    end
  end

  test "escalated scope returns only escalated conversations" do
    Conversation.escalated.each do |c|
      assert_equal "escalated", c.status
    end
  end
end
