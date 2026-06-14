require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "valid with required fields" do
    conversation = conversations(:open_conversation)
    message = Message.new(conversation: conversation, role: "user", body: "Hello")
    assert message.valid?
  end

  test "belongs to a conversation" do
    message = messages(:user_message)
    assert_equal conversations(:open_conversation), message.conversation
  end

  test "role is required" do
    message = Message.new(body: "Hello")
    message.valid?
    assert_includes message.errors[:role], "can't be blank"
  end

  test "role must be a valid value" do
    message = Message.new(role: "invalid_role", body: "Hello")
    message.valid?
    assert_includes message.errors[:role], "is not included in the list"
  end

  test "accepts all valid roles" do
    conversation = conversations(:open_conversation)
    Message::ROLES.each do |role|
      message = Message.new(conversation: conversation, role: role, body: "Test")
      assert message.valid?, "Expected role '#{role}' to be valid"
    end
  end

  test "body is required" do
    message = Message.new(role: "user")
    message.valid?
    assert_includes message.errors[:body], "can't be blank"
  end

  test "conversation is required" do
    message = Message.new(role: "user", body: "Hello")
    assert_not message.valid?
    assert_includes message.errors[:conversation], "must exist"
  end

  test "author is optional (nil for bot messages)" do
    conversation = conversations(:open_conversation)
    message = Message.new(conversation: conversation, role: "assistant", body: "Bot reply")
    assert message.valid?
    assert_nil message.author
  end

  test "user? returns true for user role" do
    assert messages(:user_message).user?
  end

  test "user? returns false for non-user role" do
    assert_not messages(:assistant_message).user?
  end

  test "assistant? returns true for assistant role" do
    assert messages(:assistant_message).assistant?
  end

  test "system? returns true for system role" do
    assert messages(:system_message).system?
  end

  test "user_messages scope returns only user messages" do
    Message.user_messages.each do |m|
      assert_equal "user", m.role
    end
  end

  test "assistant_messages scope returns only assistant messages" do
    Message.assistant_messages.each do |m|
      assert_equal "assistant", m.role
    end
  end

  test "author can be polymorphic" do
    conversation = conversations(:open_conversation)
    message = Message.new(
      conversation: conversation,
      role: "user",
      body: "Hello",
      author_type: "Customer",
      author_id: 1
    )
    assert message.valid?
    assert_equal "Customer", message.author_type
    assert_equal 1, message.author_id
  end

  test "has response, retrieval, review, action, upload, and feedback associations" do
    message = messages(:assistant_message)
    assert_equal bot_responses(:standard_response), message.bot_response
    assert_equal 2, message.retrieval_results.count
    assert_includes message.knowledge_documents, knowledge_documents(:refund_policy)
    assert_respond_to message, :human_reviews
    assert_respond_to message, :support_actions
    assert_respond_to message, :uploads
    assert_equal [ feedbacks(:helpful_response) ], message.feedbacks.to_a
  end

  test "chronological scope orders by creation time then id" do
    messages = Message.chronological.to_a
    assert_equal messages.sort_by { |message| [ message.created_at, message.id ] }, messages
  end
end
