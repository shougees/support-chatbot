require "test_helper"

module SupportBot
  class ProviderRequestTest < ActiveSupport::TestCase
    test "exposes recent messages and retrieved knowledge context" do
      conversation = conversations(:open_conversation)
      message = conversation.publish_customer_message!(body: "Where is my order?", customer: customers(:one))

      request = ProviderRequest.new(
        conversation: conversation,
        message: message,
        bot_agent: bot_agents(:support_bot),
        retrieved_documents: [ knowledge_documents(:refund_policy) ]
      )

      assert_includes request.recent_messages.map { |item| item[:body] }, message.body
      assert_equal [ knowledge_documents(:refund_policy).title ], request.knowledge_context.map { |item| item[:title] }
      assert_match "Customer support request", request.prompt_text
      assert_match "Retrieved knowledge", request.prompt_text
    end
  end
end
