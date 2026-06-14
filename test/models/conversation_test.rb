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

  test "belongs to an optional customer" do
    conversation = conversations(:open_conversation)
    assert_equal customers(:one), conversation.customer

    conversation.customer = nil
    assert conversation.valid?
  end

  test "has human reviews, support actions, and uploads" do
    conversation = conversations(:pending_human_review_conversation)
    assert_respond_to conversation, :human_reviews
    assert_respond_to conversation, :support_actions
    assert_respond_to conversation, :uploads
  end

  test "pending_human_review? returns true when status is pending_human_review" do
    conversation = conversations(:pending_human_review_conversation)
    assert conversation.pending_human_review?
  end

  test "pending_human_review? returns false when status is not pending_human_review" do
    conversation = conversations(:open_conversation)
    assert_not conversation.pending_human_review?
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

  test "pending_human_review scope returns only pending human review conversations" do
    Conversation.pending_human_review.each do |c|
      assert_equal "pending_human_review", c.status
    end
  end
end
