require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "valid with required fields" do
    conversation = conversations(:open_conversation)
    message = Message.new(
      conversation: conversation,
      public_role: "customer",
      origin: "customer_submitted",
      position: 3,
      body: "Hello"
    )

    assert message.valid?
  end

  test "belongs to a conversation" do
    message = messages(:user_message)
    assert_equal conversations(:open_conversation), message.conversation
  end

  test "public role is required" do
    message = Message.new(origin: "customer_submitted", position: 3, body: "Hello")
    message.valid?
    assert_includes message.errors[:public_role], "can't be blank"
  end

  test "public role must be a valid value" do
    message = Message.new(public_role: "assistant", origin: "customer_submitted", position: 3, body: "Hello")
    message.valid?
    assert_includes message.errors[:public_role], "is not included in the list"
  end

  test "accepts all valid public roles" do
    conversation = conversations(:open_conversation)
    Message::PUBLIC_ROLES.each_with_index do |public_role, index|
      message = Message.new(
        conversation: conversation,
        public_role: public_role,
        origin: public_role == "customer" ? "customer_submitted" : "system_event",
        position: index + 3,
        body: "Test"
      )
      assert message.valid?, "Expected public_role '#{public_role}' to be valid"
    end
  end

  test "origin is required" do
    message = Message.new(public_role: "customer", position: 3, body: "Hello")
    message.valid?
    assert_includes message.errors[:origin], "can't be blank"
  end

  test "origin must be a valid value" do
    message = Message.new(public_role: "support", origin: "assistant", position: 3, body: "Hello")
    message.valid?
    assert_includes message.errors[:origin], "is not included in the list"
  end

  test "position is required and unique per conversation" do
    duplicate = Message.new(
      conversation: conversations(:open_conversation),
      public_role: "support",
      origin: "operator_direct",
      position: 2,
      body: "Duplicate position"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:position], "has already been taken"
  end

  test "body is required" do
    message = Message.new(public_role: "customer", origin: "customer_submitted", position: 3)
    message.valid?
    assert_includes message.errors[:body], "can't be blank"
  end

  test "conversation is required" do
    message = Message.new(public_role: "customer", origin: "customer_submitted", position: 1, body: "Hello")
    assert_not message.valid?
    assert_includes message.errors[:conversation], "must exist"
  end

  test "author and published by are optional" do
    conversation = conversations(:open_conversation)
    message = Message.new(
      conversation: conversation,
      public_role: "support",
      origin: "bot_auto_sent",
      position: 3,
      body: "Support reply"
    )

    assert message.valid?
    assert_nil message.author
    assert_nil message.published_by
  end

  test "customer? returns true for customer public role" do
    assert messages(:user_message).customer?
  end

  test "support? returns true for support public role" do
    assert messages(:support_message).support?
  end

  test "system? returns true for system public role" do
    assert messages(:system_message).system?
  end

  test "customer messages scope returns only customer messages" do
    Message.customer_messages.each do |message|
      assert_equal "customer", message.public_role
    end
  end

  test "support messages scope returns only support messages" do
    Message.support_messages.each do |message|
      assert_equal "support", message.public_role
    end
  end

  test "author can be polymorphic" do
    conversation = conversations(:open_conversation)
    message = Message.new(
      conversation: conversation,
      public_role: "customer",
      origin: "customer_submitted",
      position: 3,
      body: "Hello",
      author_type: "Customer",
      author_id: 1,
      published_by_type: "Customer",
      published_by_id: 1
    )

    assert message.valid?
    assert_equal "Customer", message.author_type
    assert_equal 1, message.author_id
    assert_equal "Customer", message.published_by_type
    assert_equal 1, message.published_by_id
  end

  test "has draft, retrieval, review, action, upload, and feedback associations" do
    message = messages(:support_message)

    assert_equal response_drafts(:standard_response), message.response_draft
    assert_equal 2, message.retrieval_results.count
    assert_includes message.knowledge_documents, knowledge_documents(:refund_policy)
    assert_respond_to message, :response_reviews
    assert_respond_to message, :support_actions
    assert_respond_to message, :uploads
    assert_equal [ feedbacks(:helpful_response) ], message.feedbacks.to_a
  end

  test "chronological scope orders by conversation and position" do
    messages = Message.chronological.to_a

    assert_equal messages.sort_by { |message| [ message.conversation_id, message.position, message.created_at, message.id ] }, messages
  end
end
