require "test_helper"

class BotResponseJobTest < ActiveJob::TestCase
  test "calls bot orchestration service for a customer message" do
    conversation = conversations(:open_conversation)
    message = conversation.publish_customer_message!(body: "Where is my order?", customer: customers(:one))
    calls = []

    with_stubbed_bot_orchestrator(->(**kwargs) { calls << kwargs }) do
      BotResponseJob.perform_now(conversation, message)
    end

    assert_equal 1, calls.size
    assert_equal conversation, calls.first[:conversation]
    assert_equal message, calls.first[:message]
  end

  test "successful job publishes bot response through orchestration" do
    conversation = Conversation.create!(customer: customers(:one), status: "open")
    message = conversation.publish_customer_message!(body: "Where is my order?", customer: customers(:one))

    assert_difference("Message.support_messages.count", 1) do
      BotResponseJob.perform_now(conversation, message)
    end

    support_message = conversation.messages.support_messages.order(:position).last
    assert_equal "bot_auto_sent", support_message.origin
    assert_equal "waiting_on_customer", conversation.reload.status
  end

  test "failed job creates fallback operator review state" do
    conversation = Conversation.create!(customer: customers(:one), status: "open")
    message = conversation.publish_customer_message!(body: "Where is my order?", customer: customers(:one))

    with_stubbed_bot_orchestrator(->(**) { raise StandardError, "provider unavailable" }) do
      assert_difference("ResponseDraft.count", 1) do
        assert_difference("ResponseReview.count", 1) do
          BotResponseJob.perform_now(conversation, message)
        end
      end
    end

    response_draft = conversation.response_drafts.order(:created_at).last
    response_review = response_draft.response_reviews.last

    assert_equal "pending_operator_review", conversation.reload.status
    assert_not_nil conversation.operator_review_requested_at
    assert_equal "pending_review", response_draft.status
    assert_equal 0, response_draft.confidence
    assert_equal "fallback", response_draft.category
    assert_match /having trouble checking this automatically/, response_draft.body
    assert_equal "pending", response_review.status
    assert_equal "response_publication", response_review.key_decision
  end

  private

  def with_stubbed_bot_orchestrator(callable)
    singleton_class = class << BotOrchestrator; self; end
    original_method = BotOrchestrator.method(:call)

    singleton_class.define_method(:call) do |**kwargs|
      callable.call(**kwargs)
    end

    yield
  ensure
    singleton_class.define_method(:call) do |**kwargs|
      original_method.call(**kwargs)
    end
  end
end
