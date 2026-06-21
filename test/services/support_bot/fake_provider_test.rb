require "test_helper"

module SupportBot
  class FakeProviderTest < ActiveSupport::TestCase
    test "returns deterministic success response for general support" do
      request = provider_request(body: "Where is my order?")

      response = FakeProvider.new.call(request)

      assert_equal "draft", response.status
      assert_equal "general_support", response.category
      assert_operator response.confidence, :>, 70
      assert_match "We can help", response.body
      assert_not response.failure?
    end

    test "returns upload request response for damaged item evidence" do
      request = provider_request(body: "My item arrived damaged and broken.")

      response = FakeProvider.new.call(request)

      assert_equal "draft", response.status
      assert_equal "damaged_item", response.category
      assert response.upload_requested
      assert_equal "image", response.upload_type
    end

    test "returns review response for high risk or action decision" do
      request = provider_request(body: "Can we process a refund?")

      response = FakeProvider.new.call(request)

      assert_equal "pending_review", response.status
      assert_equal "operator_review", response.category
      assert_match "operator review", response.review_reason
    end

    private

    def provider_request(body:)
      conversation = conversations(:open_conversation)
      message = conversation.publish_customer_message!(body: body, customer: customers(:one))

      ProviderRequest.new(
        conversation: conversation,
        message: message,
        bot_agent: bot_agents(:support_bot),
        retrieved_documents: [ knowledge_documents(:refund_policy) ]
      )
    end
  end
end
