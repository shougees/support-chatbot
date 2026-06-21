require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end

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

  test "has response drafts, response reviews, support actions, and uploads" do
    conversation = conversations(:pending_operator_review_conversation)
    assert_respond_to conversation, :response_drafts
    assert_respond_to conversation, :response_reviews
    assert_respond_to conversation, :support_actions
    assert_respond_to conversation, :uploads
  end

  test "open scope returns only open conversations" do
    open_count = Conversation.open.count
    assert open_count >= 1
    Conversation.open.each do |c|
      assert_equal "open", c.status
    end
  end

  test "pending_operator_review? returns true when status is pending_operator_review" do
    conversation = conversations(:pending_operator_review_conversation)
    assert conversation.pending_operator_review?
  end

  test "pending_operator_review? returns false when status is not pending_operator_review" do
    conversation = conversations(:open_conversation)
    assert_not conversation.pending_operator_review?
  end

  test "pending_operator_review scope returns only pending operator review conversations" do
    Conversation.pending_operator_review.each do |c|
      assert_equal "pending_operator_review", c.status
    end
  end

  test "customer messages can render live conversation broadcasts" do
    conversation = Conversation.create!(customer: customers(:one), status: "open")

    assert_nothing_raised do
      perform_enqueued_jobs(only: Turbo::Streams::ActionBroadcastJob) do
        conversation.publish_customer_message!(body: "Where is my order?", customer: customers(:one))
      end
    end
  end
end
